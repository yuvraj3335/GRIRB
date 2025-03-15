terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_cognito_user_pool" "main" {
  name = "MyAppUsers"

  alias_attributes = ["email"]  
  auto_verified_attributes = ["email"]


  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  # Custom attributes
  schema {
    attribute_data_type = "Number"
    name                = "teamId"
    developer_only_attribute = false
    mutable             = true
    required            = false
    number_attribute_constraints {
      min_value = 0
      max_value = 9999
    }
  }

  mfa_configuration = "OFF"  # Change to "ON" to enable MFA

  # Email configuration (replace with your SES settings)
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

resource "aws_cognito_user_pool_client" "spring_boot_client" {
  name = "MySpringBootAppClient"

  user_pool_id                  = aws_cognito_user_pool.main.id
  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"

  # Configure proper auth flows for Spring Boot
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  # Remove incompatible OAuth scope
  allowed_oauth_scopes = ["email", "openid", "profile"]

  # Add required OAuth configuration
  allowed_oauth_flows = ["code", "implicit"]
  supported_identity_providers = ["COGNITO"]
  callback_urls        = ["http://localhost:8080/login/oauth2/code/cognito"]
  logout_urls          = ["http://localhost:8080"]

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = 1    # 1 hour
  id_token_validity      = 1    # 1 hour
  refresh_token_validity = 24   # 24 hours

  read_attributes = ["email", "custom:teamId"]
}

resource "aws_cognito_user_group" "admin" {
  name         = "ROLE_ADMIN"
  user_pool_id = aws_cognito_user_pool.main.id
  precedence   = 1
}

resource "aws_cognito_user_group" "dispatcher" {
  name         = "ROLE_DISPATCHER"
  user_pool_id = aws_cognito_user_pool.main.id
  precedence   = 2
}

# Configure token claims to include groups and teamId
resource "aws_cognito_resource_server" "resource_server" {
  identifier = "myapp"
  name       = "myapp-resource-server"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "custom.teamId"
    scope_description = "Access team ID"
  }

  scope {
    scope_name        = "cognito.groups"
    scope_description = "Access group membership"
  }
}

# Output important IDs
output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "app_client_id" {
  value = aws_cognito_user_pool_client.spring_boot_client.id
}