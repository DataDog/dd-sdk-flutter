// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:gql/ast.dart';

class OperationNameVisitor extends Visitor<String?> {
  @override
  String? visitArgumentNode(ArgumentNode node) => null;

  @override
  String? visitBooleanValueNode(BooleanValueNode node) => null;

  @override
  String? visitDefaultValueNode(DefaultValueNode node) => null;

  @override
  String? visitDirectiveDefinitionNode(DirectiveDefinitionNode node) => null;

  @override
  String? visitDirectiveNode(DirectiveNode node) => null;

  @override
  String? visitDocumentNode(DocumentNode node) => null;

  @override
  String? visitEnumTypeDefinitionNode(EnumTypeDefinitionNode node) => null;

  @override
  String? visitEnumTypeExtensionNode(EnumTypeExtensionNode node) => null;

  @override
  String? visitEnumValueDefinitionNode(EnumValueDefinitionNode node) => null;

  @override
  String? visitEnumValueNode(EnumValueNode node) => null;

  @override
  String? visitFieldDefinitionNode(FieldDefinitionNode node) => null;

  @override
  String? visitFieldNode(FieldNode node) => null;

  @override
  String? visitFloatValueNode(FloatValueNode node) => null;

  @override
  String? visitFragmentDefinitionNode(FragmentDefinitionNode node) => null;

  @override
  String? visitFragmentSpreadNode(FragmentSpreadNode node) => null;

  @override
  String? visitInlineFragmentNode(InlineFragmentNode node) => null;

  @override
  String? visitInputObjectTypeDefinitionNode(
          InputObjectTypeDefinitionNode node) =>
      null;

  @override
  String? visitInputObjectTypeExtensionNode(
          InputObjectTypeExtensionNode node) =>
      null;

  @override
  String? visitInputValueDefinitionNode(InputValueDefinitionNode node) => null;

  @override
  String? visitIntValueNode(IntValueNode node) => null;

  @override
  String? visitInterfaceTypeDefinitionNode(InterfaceTypeDefinitionNode node) =>
      null;

  @override
  String? visitInterfaceTypeExtensionNode(InterfaceTypeExtensionNode node) =>
      null;

  @override
  String? visitListTypeNode(ListTypeNode node) => null;

  @override
  String? visitListValueNode(ListValueNode node) => null;

  @override
  String? visitNameNode(NameNode node) => null;

  @override
  String? visitNamedTypeNode(NamedTypeNode node) => null;

  @override
  String? visitNullValueNode(NullValueNode node) => null;

  @override
  String? visitObjectFieldNode(ObjectFieldNode node) => null;

  @override
  String? visitObjectTypeDefinitionNode(ObjectTypeDefinitionNode node) => null;

  @override
  String? visitObjectTypeExtensionNode(ObjectTypeExtensionNode node) => null;

  @override
  String? visitObjectValueNode(ObjectValueNode node) => null;

  @override
  String? visitOperationDefinitionNode(OperationDefinitionNode node) =>
      node.name?.value;

  @override
  String? visitOperationTypeDefinitionNode(OperationTypeDefinitionNode node) =>
      null;

  @override
  String? visitScalarTypeDefinitionNode(ScalarTypeDefinitionNode node) => null;

  @override
  String? visitScalarTypeExtensionNode(ScalarTypeExtensionNode node) => null;

  @override
  String? visitSchemaDefinitionNode(SchemaDefinitionNode node) => null;

  @override
  String? visitSchemaExtensionNode(SchemaExtensionNode node) => null;

  @override
  String? visitSelectionSetNode(SelectionSetNode node) => null;

  @override
  String? visitStringValueNode(StringValueNode node) => null;

  @override
  String? visitTypeConditionNode(TypeConditionNode node) => null;

  @override
  String? visitUnionTypeDefinitionNode(UnionTypeDefinitionNode node) => null;

  @override
  String? visitUnionTypeExtensionNode(UnionTypeExtensionNode node) => null;

  @override
  String? visitVariableDefinitionNode(VariableDefinitionNode node) => null;

  @override
  String? visitVariableNode(VariableNode node) => null;
}
