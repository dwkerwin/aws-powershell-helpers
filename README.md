## aws-powershell-helpers

This is my collection of Powershell functions that are useful when administering Amazon Web Services in a Windows environment.

# RDP-EC2Instance

Given the name of the instance, this will initiate an RDP session. If the instance hasn't fully launched yet and isn't ready to be connected to, this will continue to test the network connection until it is available and then connect.

```RDP-EC2Instance i-ab123456```

By default it tries to connect by using the public IP. If you need to connect using the private IP, use the `-privateIp` switch:

```RDP-EC2Instance i-ab123456 -privateIp```

It can also automatically decrypt the Windows password given the `-decryptPw` switch. If you have the `$Global:ec2pem` variable set with the location of your PEM file to decrypt the password, it will automatically use this, otherwise it will prompt you for the location of the PEM file.

```RDP-EC2Instance i-ab123456 -decryptPw```

# List-EC2InstancesByName

Used often in conjuction with RDP-EC2Instance, if you know the name of the instance you want to RDP into, you can enter part of that name here and this will list InstanceIds matching that name, along with VPC and tag info. Then you can use the InstanceId shown here for RDP.

```List-EC2InstancesByName Website```

Will list any instances that have "Website" in the name.

# Launch-EC2InstanceFromASGroupConfig

Ever want to launch an instance that is configured exactly matching an existing autoscaling launch configuration but launch it for testing, outside of the ELB or ASGroup?  This will do just that, and is invoked as simply as:

 ```Launch-EC2InstanceFromASGroupConfig MyASGName```

This will launch an EC2 instance with all the characteristics of the specified autoscaling group. It will get the launch configuration from the ASGroup, use the first subnet configured for the ASGroup, and propagate the EC2 tags to the new instance as well.  It will append ("Test Launch") to the name of the instance so that it stands out from instances that are actually members of the ASGroup.

Optionally, if you want to use the subnet and tags from the autoscaling group, but specify an alternate launch configuration, you can do so with the `-overrideLaunchConfigName` argument. This is useful when testing alternate EC2 userdata.

```Launch-EC2InstanceFromASGroupConfig MyASGName -overrideLaunchConfigName SomeDifferentLCName```

# Launch-EC2InstanceFromLaunchConfig

If you want to launch from a Launch Configuration directly, you can use this. You must pass a subnet. This will not name the instance or propagate any tags.

```Launch-EC2InstanceFromLaunchConfig MyLCName -subnetId subnet-12345678```

