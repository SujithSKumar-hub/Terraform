resoource "aws_vpc" "blog" {

  cidr_block = "172.16.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "blog"
    
  }
}

##################################################################
# subnet - public1
##################################################################

resource "aws_subnet" "public1" {
  vpc_id     = aws_vpc.blog.id
  cidr_block = "172.16.0.0/19"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "blog-public1"
  }
}

##################################################################
# subnet - public2
##################################################################

resource "aws_subnet" "public2" {
  vpc_id     = aws_vpc.blog.id
  cidr_block = "172.16.32.0/19"
  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "blog-public2"
  }
}

##################################################################
# subnet - private
##################################################################

resource "aws_subnet" "private1" {
  vpc_id     = aws_vpc.blog.id
  cidr_block = "172.16.64.0/19"
  availability_zone = "us-east-2c"
  map_public_ip_on_launch = false
  tags = {
    Name = "blog-private1"
  }
}
##################################################################
# subnet - internet gateway
##################################################################


resource "aws_internet_gateway" "blog" {
  vpc_id = aws_vpc.blog.id

  tags = {
    Name = "blog-igw"
  }
}


##################################################################
# Elastic Ip Creation
##################################################################
resource "aws_eip" "nat" {
  
  vpc      = true
}

##################################################################
# subnet - NAT gateway
##################################################################

resource "aws_nat_gateway" "Nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public2.id
}

##################################################################
# subnet -Route table
##################################################################

resource "aws_route_table" "public" {
  
 vpc_id = aws_vpc.blog.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog.id
  }

  tags = {
    Name = "blog-public"
  }
}


resource "aws_route_table" "private" {
  
 vpc_id = aws_vpc.blog.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.Nat-gw.id
  }

  tags = {
    Name = "blog-private"
  }
}
##################################################################
# subnet-public1 - routetable-public 
##################################################################
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

##################################################################
# subnet-public2 - routetable-public 
##################################################################
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}


##################################################################
# subnet-private - routetable-private
##################################################################
resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}


##################################################################
# security group bastion
##################################################################


resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.blog.id

  ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion"
  }
}

##################################################################
# security group Webserver
##################################################################
resource "aws_security_group" "Webserver" {
  name        = "Webserver"
  description = "Allow ssh from bastion , 80 from all"
  vpc_id      = aws_vpc.blog.id 

  ingress {
    
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]

  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Webserver"
  }
}



##################################################################
# security group database
##################################################################

resource "aws_security_group" "database" {
  
  name        = "database"
  description = "Allow ssh from bastion , 3306 from webserver"
  vpc_id      = aws_vpc.blog.id 
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ aws_security_group.Webserver.id ]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ aws_security_group.bastion.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database"
  }
}

#######################################################################
# Creating SshKey Pair
#######################################################################


  resource "aws_key_pair" "keypair" {
  key_name   = "newkey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQJXBldXiS+VpEvkMqD9H1ttg3CylgTxczU9UsLdi1noaab8J1Bzhr2krBn33rnEyZzu7VSWw1czTeZYQM/r8M0Qz1YzI1qu//5LK41675KiXME5ys5OKEooaOeIOa/VBZ89D9hXz78CtibpGy2z5Mjd4ab9OZreQLgDK5T+iJcTxBHVwpsdh+9uYxOCMUgD61yf55Aph5L51sHjJ4FDORDoYo2Kdkr7IsbgPtvpp9nwqUVQY2bvIXrzzm9UrOLBHwI3H524/DV0cklNcy2mGrwvP4MRZt+ReGdvVL0fYaAAFBeAQEoLGWysFL6o4V/RlUbAxrIrAS5gmjmAJYxPGn SujithSKumar@DESKTOP-GUA7JQB"
}

#######################################################################
# bastion ec2
#######################################################################
resource "aws_instance" "bastion" {
    
  ami           = "ami-03657b56516ab7912"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.bastion.id ]
  associate_public_ip_address = true
  key_name = aws_key_pair.keypair.key_name
  subnet_id = aws_subnet.public2.id
  tags = {
    Name = "bastion"
  }
}




#######################################################################
# webserver ec2
#######################################################################

resource "aws_instance" "Webserver" {
    
  ami           = "ami-03657b56516ab7912"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.Webserver.id ]
  associate_public_ip_address = true
  key_name = aws_key_pair.keypair.key_name
  subnet_id = aws_subnet.public1.id
  tags = {
    Name = "webserver"
  }
}

#######################################################################
# database ec2
#######################################################################


resource "aws_instance" "database" {
    
  ami           = "ami-03657b56516ab7912"
  instance_type = "t2.micro"
  vpc_security_group_ids = [ aws_security_group.database.id ]
  associate_public_ip_address = false
  key_name = aws_key_pair.keypair.key_name
  subnet_id = aws_subnet.private1.id
  tags = {
    Name = "database"
  }
}


