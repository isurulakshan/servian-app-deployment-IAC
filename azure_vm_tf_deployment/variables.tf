#Target customer subscription
variable "subscription_id" {
  type = string
}
#Azure SPN client id
variable "client_id" {
  type = string
}
#Azure SPN client secret
variable "client_secret" {
  type = string
}
#Azure tenant id
variable "tenant_id" {
  type = string
}
#Azure location
variable "location" {
  default = "westus2"
  type    = string
}
#Customer environment for resource tags
variable "environment" {
  default = "PRD"
  type    = string
}
#Customer name
variable "customer_name" {
  default = "servian"
  type    = string
}
