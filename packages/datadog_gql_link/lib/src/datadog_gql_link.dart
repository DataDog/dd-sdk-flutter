// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:gql/ast.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:uuid/uuid.dart';

import 'operation_name_visitor.dart';

class _GraphQLAttributes {
  static const operationType = '_dd.graphql.operation_type';
  static const operationName = '_dd.graphql.operation_name';
  static const variables = '_dd.graphql.variables';
  static const errors = 'errors';
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
/// By default, this link will temporarily add a header (`x-datadog-graphql-resource-id`)
/// to your http request that is removed by the `datadog_tracking_http_client`.
///
/// If you are not using `datadog_tracking_http_client`, or if you are using
/// a connection method that normally bypasses the `datadog_tracking_http_client`,
/// you should set [standAlone] to true. This will prevent the link from
/// adding the temporary header.
///
/// This Link is not a terminating link.
class DatadogGqlLink extends Link {
  final DatadogSdk datadogSdk;
  final DatadogGqlListener? listener;
  final Uri uri;

  final _uuid = const Uuid();

  DatadogGqlLink(
    this.datadogSdk,
    this.uri, {
    this.listener,
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
    bool shouldSample = false;
    TracingContext? tracingContext;
    if (tracingHeaderTypes.isNotEmpty) {
      shouldSample = rum.shouldSampleTrace();
      tracingContext = generateTracingContext(shouldSample);
    }

    final internalAttributes = _getInternalAttributes(request);
    Map<String, Object?> userAttributes = {};
    listener?.requestStarted(request, userAttributes);
    request = _injectTracingHeaders(request);

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

        final errorMap = _serializeResponseErrors(data);

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
          bool shouldSample = rum.shouldSampleTrace();
          var headers = context?.headers ?? <String, String>{};

          // No tracing context, generate one ourselves
          final tracingContext = generateTracingContext(shouldSample);

          for (final headerType in tracingHeaderTypes) {
            final newHeaders = getTracingHeaders(tracingContext, headerType,
                contextInjection: rum.contextInjectionSetting);
            for (final entry in newHeaders.entries) {
              // Don't replace exiting headers
              if (!headers.containsKey(entry.key)) {
                headers[entry.key] = entry.value;
              }
            }
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

  Map<String, Object?>? _serializeResponseErrors(Response response) {
    if (response.errors?.isEmpty ?? true) return null;

    final serializedErrors = response.errors!.map((e) {
      return {
        'message': e.message,
        'locations': e.locations?.map((l) => {
              'line': l.line,
              'column': l.column,
            }),
        'path': e.path
      };
    });
    return {
      '_dd': {
        'graphql': {
          _GraphQLAttributes.errors: serializedErrors,
        }
      }
    };
  }
}
