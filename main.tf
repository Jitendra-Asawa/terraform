output "aws-resource-dns" {
  value = aws_instance.ec2-test-instance.public_dns
}

output "key" {
  value = tls_private_key.private-key.private_key_pem
}

provider "aws" {
  profile = "default"
  version = "~> 2.0"
  region  = "us-east-1"
}

# Block to generate key
resource "tls_private_key" "private-key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Block to pair the generated key with a name
resource "aws_key_pair" "generated-key" {
  key_name   = "ec2-test-key"
  public_key = "${tls_private_key.private-key.public_key_openssh}"
}

resource "aws_instance" "ec2-test-instance" {
  instance_type = "t2.micro"
  ami           = "ami-0b777777777777777"
  key_name      = "${aws_key_pair.generated-key.key_name}"
  #key_name               = "ec2-test-instance"
  #vpc_security_group_ids = ["sg-0275sf7s5s6ad07"]
  #subnet_id = "subnet-377f778"

  tags = {
    Name = "ec2-test-instance"
  }

}

# Changing the value in the block "triggers" will help in remote execution of the 
# bash script everytime on the aws-instance as null-resource will be recreated everytime
resource "null_resource" "test-null-resource" {
  triggers = {
    value = "${timestamp()}",
  }
  provisioner "local-exec" {
    command = "echo 'aws_instance local-exec working'"
  }

  provisioner "file" {
    source      = "/home/user/dump/aws-test/test-script-deployable.sh"
    destination = "/home/ec2-user/test-script-deployable.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'I am executed remotely now.'",
      "chmod +x /home/ec2-user/test-script-deployable.sh",
      "sh /home/ec2-user/test-script-deployable.sh",
      "echo 'Remote-Exec complete'",
    ]
  }

  # Connect to EC2 instance to execute bash commands and scripts
  connection {
    type = "ssh"
    host = "${aws_instance.ec2-test-instance.public_ip}"
    user = "ec2-user"
    #private_key = "${file("/home/user/ec2-test-instance.pem")}"
    private_key = "${tls_private_key.private-key.private_key_pem}"
  }

  # Ensures that this resource will be created after the key-pair is created
  depends_on = [aws_key_pair.generated-key]

}
