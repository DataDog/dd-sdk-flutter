// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:gql/ast.dart';
import 'package:gql/language.dart' show printNode;
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:uuid/uuid.dart';

import 'operation_name_visitor.dart';

class _GraphQLAttributes {
  static const operationType = '_dd.graphql.operation_type';
  static const operationName = '_dd.graphql.operation_name';
  static const variables = '_dd.graphql.variables';
  static const payload = '_dd.graphql.payload';
  static const errors = '_dd.graphql.errors';
}

abstract interface class DatadogGqlListener {
  void requestStarted(Request request, Map<String, Object?> attributes);
  void responseReceived(Response response, Map<String, Object?> attributes);
  void requestError(
      Object error, StackTrace stackTrace, Map<String, Object?> attributes);
}

/// DatadogGqlLink automatically creates RUM Resources, enables distributed
/// traces with first party hosts (specified in [DatadogSdk.firstPartyHosts]),
/// and automatically adds GraphQL attributes visible in both APM and RUM.
///
/// This link can be used on its own or with `datadog_tracking_http_client`.
///
/// This Link is not a terminating link.
class DatadogGqlLink extends Link {
  final DatadogSdk datadogSdk;
  final DatadogGqlListener? listener;
  final Uri uri;

  final _uuid = const Uuid();

  /// When `true`, the full GraphQL document (query or mutation string) is
  /// captured in the RUM resource event
  ///
  /// Defaults to `false`.
  final bool trackPayload;

  DatadogGqlLink(
    this.datadogSdk,
    this.uri, {
    this.listener,
    this.trackPayload = false,
  });

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    assert(
      forward != null,
      'DatadogGqlLink is not a terminating link and needs a NextLink',
    );

    final rum = datadogSdk.rum;
    if (rum == null) {
      return forward!(request);
    }

    final tracingHeaderTypes = datadogSdk.headerTypesForHost(uri);
    final internalAttributes = _getInternalAttributes(request);

    TracingContext? tracingContext;
    try {
      if (tracingHeaderTypes.isNotEmpty) {
        tracingContext = generateTracingContext(datadogSdk, rum);
      }

      request = _injectTracingHeaders(request);
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogGqlLink encountered an error attempting to create a tracing context; $e',
        st,
        e.runtimeType.toString(),
      );
    }

    Map<String, Object?> userAttributes = {};
    listener?.requestStarted(request, userAttributes);
    final resourceId = _startRumResource(
        request, internalAttributes, tracingContext, userAttributes);

    return forward!(request).transform(StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        listener?.responseReceived(data, userAttributes);

        var linkResponseContext = data.context.entry<HttpLinkResponseContext>();
        int? statusCode;
        int? size;
        if (linkResponseContext != null) {
          statusCode = linkResponseContext.statusCode;
          final contentLength = linkResponseContext.headers?['content-length'];
          if (contentLength != null) {
            size = int.tryParse(contentLength);
          }
        }

        Map<String, Object?>? errorMap;
        try {
          errorMap = _serializeResponseErrors(data);
        } catch (e, st) {
          datadogSdk.internalLogger.sendToDatadog(
            '$DatadogGqlLink encountered an error serializing errors; $e',
            st,
            e.runtimeType.toString(),
          );
        }

        datadogSdk.rum?.stopResource(
          resourceId,
          statusCode,
          RumResourceType.native,
          size,
          {
            if (errorMap != null) ...errorMap,
            ...userAttributes,
          },
        );

        sink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        listener?.requestError(error, stackTrace, userAttributes);
        datadogSdk.rum?.stopResourceWithErrorInfo(resourceId, error.toString(),
            error.runtimeType.toString(), userAttributes);

        sink.addError(error, stackTrace);
      },
    ));
  }

  Map<String, String> _getInternalAttributes(Request request) {
    final attributes = <String, String>{};

    final operationType = request.operation.getOperationType();
    if (operationType != null) {
      switch (operationType) {
        case OperationType.mutation:
          attributes[_GraphQLAttributes.operationType] = 'mutation';
          break;
        case OperationType.subscription:
          attributes[_GraphQLAttributes.operationType] = 'subscription';
          break;
        case OperationType.query:
          attributes[_GraphQLAttributes.operationType] = 'query';
          break;
      }
    }

    var operationName = request.operation.operationName;
    if (operationName == null) {
      final visitor = OperationNameVisitor();

      operationName = request.operation.document.definitions
          .map((d) => d.accept(visitor))
          .whereType<String>()
          .firstOrNull;
    }

    if (operationName != null) {
      attributes[_GraphQLAttributes.operationName] = operationName;
    }

    try {
      attributes[_GraphQLAttributes.variables] = jsonEncode(
        request.variables,
        toEncodable: (nonEncodable) {
          // Non-encodable variables should just use their string representations
          return nonEncodable.toString();
        },
      );
    } catch (e, st) {
      datadogSdk.internalLogger.error('Error encodeing GraphQL variables: $e.');
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogGqlLink encountered an error while attempting to encode variables: $e',
        st,
        e.runtimeType.toString(),
      );
    }

    if (trackPayload) {
      try {
        attributes[_GraphQLAttributes.payload] =
            printNode(request.operation.document);
      } catch (e, st) {
        datadogSdk.internalLogger.sendToDatadog(
          '$DatadogGqlLink encountered an error while attempting to serialize payload: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }

    return attributes;
  }

  String _startRumResource(
      Request request,
      Map<String, String> internalAttributes,
      TracingContext? tracingContext,
      Map<String, Object?> userAttributes) {
    final resourceId = _uuid.v1();
    final datadogAttributes = generateDatadogAttributes(
        tracingContext, datadogSdk.rum?.traceSampleRate ?? 0);
    final attributes = {
      ...userAttributes,
      ...datadogAttributes,
      ...internalAttributes,
    };

    // TODO: RUM-1027 - Assume `post` for now, but most links support `get` queries.
    datadogSdk.rum?.startResource(
        resourceId, RumHttpMethod.post, uri.toString(), attributes);

    return resourceId;
  }

  Request _injectTracingHeaders(Request request) {
    try {
      final rum = datadogSdk.rum;
      final tracingHeaderTypes = datadogSdk.headerTypesForHost(uri);

      if (rum != null && tracingHeaderTypes.isNotEmpty) {
        return request.updateContextEntry<HttpLinkHeaders>((context) {
          var headers = context?.headers ?? <String, String>{};

          // No tracing context, generate one ourselves
          final tracingContext = generateTracingContext(datadogSdk, rum);

          for (final headerType in tracingHeaderTypes) {
            injectTracingHeaders(tracingContext, headerType, headers,
                contextInjection: rum.contextInjectionSetting);
          }

          return HttpLinkHeaders(headers: headers);
        });
      }
    } catch (e, st) {
      datadogSdk.internalLogger.sendToDatadog(
        '$DatadogGqlLink encountered an error while attempting to inject headers call: $e',
        st,
        e.runtimeType.toString(),
      );
    }

    return request;
  }

  Map<String, Object>? _serializeResponseErrors(Response response) {
    if (response.errors?.isEmpty ?? true) return null;

    final serializedErrors = response.errors!.map((e) {
      return {
        'message': e.message,
        'locations': e.locations
            ?.map((l) => {
                  'line': l.line,
                  'column': l.column,
                })
            .toList(),
        'path': e.path,
        if (e.extensions?['code'] != null) 'code': e.extensions!['code'],
      };
    }).toList();
    return {
      _GraphQLAttributes.errors: json.encode(serializedErrors),
    };
  }
}
