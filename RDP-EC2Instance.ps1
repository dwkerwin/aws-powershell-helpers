<#
.SYNOPSIS
Initiates an RDP connection to an AWS EC2 instance given the instance name
.PARAMETER instanceId
The AWS name of the instance, e.g. 'i-ab123456'
.PARAMETER decryptPw
Optional. If set this will attempt to decrypt the password and copy it to the clipboard.
The .PEM private key is necessary to decrypt the password. Specify this full file path
in $Global:ec2pw so that this can occur automatically. If the variable is null, you
will be prompted to enter it.
.PARAMETER privateIp
Optional. If set, indicates it should try to connect to the instance using the
private IP address.  If omitted, will use the public IP.
.EXAMPLE
Connect via private IP, and decrypt the password and copy it to the clipboard
    rdpe i-ab123456 -p -d
or the more verbose version of the same thing
    rdpe -instanceId i-ab123456 -privateIp -decryptPw
#>
function RDP-EC2Instance($instanceId, [switch]$decryptPw, [switch]$privateIp) {
    # Of course this has a dependency on the AWSPowerShell module
    if (!(Get-Module -Name "AWSPowerShell")) {
        echo "AWSPowerShell module not loaded! Download and install from:"
        echo "http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi"
        return
    }

    $instanceStatus = Get-EC2InstanceStatus -InstanceId $instanceId
    if ($instanceStatus.InstanceState.Code -ne 16) {
        echo "Instance is not in a running state."
        if ($status) {
            echo "Instance State: $instanceStatus.InstanceState.Name ($($instanceStatus.InstanceState.Code))"
            echo "Instance Status: $($instanceStatus.InstanceState.Name), Status: $($instanceStatus.Status.Details): $($instanceStatus.Status.Status)"
        }
        return
    }

    if ($privateIp.IsPresent) {
        $ipaddr = (Get-EC2Instance -Instance $instanceId).Instances[0].PrivateIpAddress
    } else {
        $ipaddr = (Get-EC2Instance -Instance $instanceId).Instances[0].PublicIpAddress
    }
    
    # wait until we can connect (if the instance was just started it may not be ready yet)
    # wait for connection before attempting to decrypt windows password
    do {
        $conTest = Test-NetConnection -ComputerName $ipaddr -CommonTCPPort RDP
    } until ($conTest.TcpTestSucceeded -eq $true)

    if ($decryptPw.IsPresent) {
        if ($Global:ec2pem) {
            $pemPath = $Global:ec2pem
        } else {
            echo "Private key file needed to decrypt the Windows password."
            echo "You can store this in `$Global:ec2pem to avoid typing it here in the future."
            $pemPath = read-host -prompt "Full path including filename to the .PEM file"
            if ( ([string]::IsNullOrEmpty($pemPath)) -or (!(test-path $pemPath)) ) {
                echo "PEM file path invalid."
                return
            }
            $pemViaUserInput = $true
        }
        if (!(test-path $pemPath)) {
            echo "PEM file path specified is not found: $pemPath"
            return
        } else {
            $pwEncrypted = Get-EC2PasswordData -InstanceId $instanceId
            if ($pwEncrypted -eq $null) {
                echo "A password is not yet available for this instance. It may still be booting up."
                return
            }
            $pw = Get-EC2PasswordData -InstanceId $instanceId -PemFile $pemPath
        }
    } else {
        # if no password parameter is sent, try to use the Global, if one was set
        if ($Global:ec2pw -eq $null) {
            echo "Note: `$Global:ec2pw not set. For pw assistance, set `$Global:ec2pw or use -decryptPw retrieve the EC2 automatically generated password."
        } else {
            $pw = $Global:ec2pw
        }
    }
    if ($pw) {
        # copy the password to the clipboard so it can be easily pasted into the RDP window
        $pw | clip
        echo "Password copied to clipboard."
        if ($pemViaUserInput) {
            $Global:ec2pem = $pemPath
            echo "Stored .PEM file path in `$Global:ec2pem so you don't have to be prompted in the future."
        }
    }

    # initiate the RDP connection
    # handy tip - use the down arrow key to enter a new username such as Administrator
    mstsc /v:$ipaddr
}
set-alias rdpe RDP-EC2Instance

