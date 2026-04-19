# Terraform VPC
Create a VPC with a standard, opinionated layout.

## Subnets
This module creates an equal number of public and private subnets (if private subnets are enabled) - 1 each per availability zone. Specify the availability zones you want to create the subnets.

> WARNING: Changing the availability zones after initial provisioning is not possible because it will recalculate the subnet addresses.

By default public subnets are created with 254 addresses and private subnets are created with 2046 addresses. You can change the size of the subnets by specifying `public_subnet_newbits` and `private_subnet_newbits`. Newbits is the number of bits to add to the base network bits. For example, if you have a /16 network and want subnets of /22, then newbits is 6.

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
module "my_vpc" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=vpc/vX.Y.Z"

  aws_region   = "us-east-0"
  project_name = "alpha"
  vpc_cidr     = "192.168.64.0/18"

  vpc_tags = {
    project     = "ledgerrun"
    account     = "<ACCOUNT NAME>"
    environment = "<ENVIRONMENT>"
    layer       = "networking"
    managedby   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.1.0 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.0 |



## Resources

| Name | Type |
|------|------|
| [aws_eip.nat_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.vpc_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_internet_gateway.vpc_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_acl.vpc_network_acl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl) | resource |
| [aws_route.private_nat_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet_gateway_route](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private_route_table_assciation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public_route_table_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.vpc_flow_logs_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_security_group.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.interface_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_dhcp_options.vpc_dhcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options) | resource |
| [aws_vpc_dhcp_options_association.dns_option_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association) | resource |
| [aws_vpc_endpoint.gateway_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_route_table_association) | resource |
| [aws_vpc_endpoint_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint_route_table_association) | resource |
| [aws_availability_zone.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_vpc_endpoint_service.gateway_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint_service) | data source |
| [aws_vpc_endpoint_service.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc_endpoint_service) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws\_region | This is the region that you want to create the resources in. | `string` | n/a | yes |
| project\_name | This is the name you want the VPC and related resources to have.  This is useful if running multiple projects in the same region + account. | `string` | n/a | yes |
| vpc\_cidr | Default IP CIDR block you want to use with the VPC (eg 10.0.0.0/18 or 10.0.64.0/18), see wiki page for in use cidrs: https://sparefoot.atlassian.net/l/cp/k111K3GV | `string` | n/a | yes |
| create\_vpc\_flow\_log\_bucket | Create a vpc flow log bucket, requires `enable_vpc_flow_logs` to equal true | `bool` | `false` | no |
| domain\_name\_servers | Additional DNS servers | `list(any)` | <pre>[<br/>  "AmazonProvidedDNS"<br/>]</pre> | no |
| enable\_igw | Creates Interet Gateway if set to true | `bool` | `true` | no |
| enable\_priv\_subnets | Enable the private subnets | `bool` | `true` | no |
| enable\_public\_subnets | Enable the private subnets | `bool` | `true` | no |
| enable\_vpc\_flow\_logs | Enable VPC Flow Logs | `bool` | `false` | no |
| gateway\_endpoints | A gateway that you specify as a target for a route in your route table for traffic destined to a supported AWS service. Currently supports S3 and DynamoDB services. | `set(string)` | <pre>[<br/>  "s3"<br/>]</pre> | no |
| interface\_endpoints | Names of AWS services for which to create PrivateLink interfaces in the VPC. | `set(string)` | `[]` | no |
| internal\_domain\_name | This is the domain name to use within the VPC. | `string` | `"ec2.internal"` | no |
| private\_subnet\_newbits | Number of bits to add to vpc\_cidr to create private subnet size. Ex. if vpc\_cidr is 10.0.0.0/16 and newbits is 4, then subnets are /20. | `number` | `3` | no |
| private\_subnet\_tags | Tags that are applied to private subnets only | `map(string)` | `{}` | no |
| public\_subnet\_newbits | Number of bits to add to vpc\_cidr to create public subnet size. Ex. if vpc\_cidr is 10.0.0.0/16 and newbits is 4, then subnets are /20. | `number` | `6` | no |
| public\_subnet\_tags | Tags that are applied to public subnets only | `map(string)` | `{}` | no |
| subnet\_tags | Tags that are applied to all subnets | `map(string)` | `{}` | no |
| subnet\_zone\_list | The AZs to provision subnets for | `list(string)` | <pre>[<br/>  "a",<br/>  "b",<br/>  "c"<br/>]</pre> | no |
| vpc\_flow\_log\_s3\_bucket\_arn | Bucket ARN for the VPC Flow Logs | `string` | `""` | no |
| vpc\_tags | Tags that are applied to all resources of the VPC | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| gateway\_endpoints\_by\_service | Object with the service and it's endpoint |
| interface\_endpoint\_security\_groups | Interface Endpoint Security Groups |
| interface\_endpoints | Interface Endpoints |
| private\_route\_tables | Private Subnet Route Tables |
| private\_subnet\_cidrs | Private Subent CIRDS |
| private\_subnet\_ids | Private Subnet IDs |
| public\_nat\_gateway\_cidrs | Public CIDRs for the NAT Gateways |
| public\_nat\_gateways\_by\_region | An Object with region and nat gateway for that region |
| public\_route\_tables | Public Route Tables |
| public\_subnet\_cidrs | Public Subnet CIRD's |
| public\_subnet\_ids | Public Subnet ID's |
| vpc\_cidr | VPC CIRD |
| vpc\_id | VPC ID |
<!-- END_TF_DOCS -->
