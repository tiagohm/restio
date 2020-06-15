import 'package:code_builder/code_builder.dart';

class ConstExpression extends Expression {
  @override
  final Expression expression;

  const ConstExpression(this.expression);

  @override
  R accept<R>(ExpressionVisitor<R> visitor, [R context]) {
    return expression.accept<R>(visitor, context);
  }
}
