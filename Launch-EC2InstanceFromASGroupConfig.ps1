<#
.SYNOPSIS
Launches an AWS EC2 instance with the properties of the given autoscaling group
.PARAMETER asgroupName
The name of the autoscaling group to inherit properties from
.PARAMETER overrideLaunchConfig
Optionally, provide a different launch config rather than using the LC from the ASG
.PARAMETER overrideInstanceType
Optionally, provide a different instance type rather than using the type from the LC
.EXAMPLE
Launch-EC2InstanceFromASGroupConfig MyASGName
Launch-EC2InstanceFromASGroupConfig MyASGName -overrideLaunchConfigName SomeDifferentLCName
#>

# enable invocation by script or function call
param
(
    [string]$asgroupName
);

function Launch-EC2InstanceFromASGroupConfig(
  [Parameter(Mandatory=$true)][string] $asgroupName,
  [string] $overrideLaunchConfigName,
  [string] $overrideInstanceType
  ) {
  $ErrorActionPreference = "Stop"

  echo "Querying $asgroupName"
  $asGroup = Get-ASAutoScalingGroup -AutoScalingGroupName $asgroupName
  if (!($asGroup)) {
    write-error "Autoscaling Group not found by name: $asgroupName"
    return
  }

  if ($overrideLaunchConfigName) {
    $lcName = $overrideLaunchConfigName
  } else {
    $lcName = $asGroup.LaunchConfigurationName
  }

  echo "Launch configuration $lcName"
  $instanceId = Launch-EC2InstanceFromLaunchConfig `
    -launchConfigName $lcName `
    -subnetId ($asGroup.VPCZoneIdentifier -split ',')[0] `
    -overrideInstanceType $overrideInstanceType

  if (!($instanceId)) {
    write-error "Instance was not launched"
    return
  }

  # apply any PropagateAtLaunch tags to the instance just as the autoscaling group would have
  $propagateTags = @()
  $asGroup.Tags | % {
    $keyValue = $_.Value
    # append "Test Launch" to the name so it isn't confused with real members of the ASgroup
    if ($_.Key -eq "Name") {
      $keyValue += " (Test Launch)"
      $instanceName = $keyValue
    }

    $tag = @( @{key=$_.Key;value="$keyValue"} )
    $propagateTags += $tag
  }

  $instanceId | New-EC2Tag -Tags $propagateTags

  echo "Tagged $instanceId as '$instanceName' and applied $($propagateTags.Length - 1) other tags."
}

function Launch-EC2InstanceFromLaunchConfig(
    [Parameter(Mandatory=$true)][string]$launchConfigName,
    [string]$subnetId,
    [string]$overrideInstanceType
    )
{
  $ErrorActionPreference = "Stop"

  $launchConfig = Get-ASLaunchConfiguration -LaunchConfigurationName $launchConfigName

  if ($overrideInstanceType) {
    "Using instance type $overrideInstanceType"
    $instanceType = $overrideInstanceType
  } else {
    $instanceType = $launchConfig.InstanceType
  }

  $reservation = New-EC2Instance `
    -ImageId $launchConfig.ImageId `
    -MinCount 1 -MaxCount 1 `
    -InstanceType $instanceType `
    -SecurityGroupId $launchConfig.SecurityGroups `
    -SubnetId $subnetId `
    -UserData $launchConfig.UserData `
    -InstanceProfile_Name $launchConfig.IamInstanceProfile `
    -KeyName $launchConfig.KeyName

  # sometimes a slight delay is needed before subsequent AWS API calls can use
  # the new InstanceId, so safest to insert a short pause
  sleep 3

  $instanceId = $reservation.RunningInstance[0].InstanceId
  echo $instanceId
}

# if the script was called with arguments, invoke the function
if ($asgroupName) {
  Launch-EC2InstanceFromASGroupConfig -asgroupName $asgroupName
}
