#output "Execution_ARN" {
#  value = "${aws_apigatewayv2_api.test_gateway.execution_arn}/*/*"
#}



#output "API_Endpoint_URL" {
#  value = aws_apigatewayv2_api.test_gateway.api_endpoint
#}

output "Stage_URL" {
  value = aws_apigatewayv2_stage.test_stage.invoke_url
}
