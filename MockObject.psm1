function Create-MockObject {
	$Object = New-Object PSCustomObject
	Add-Member -InputObject $Object -MemberType NoteProperty -Name "mock_functions" -Value @{}
	return $Object
}

function MockObject {
	param(
		[Parameter(Mandatory = $true)]
		[PSCustomObject]$Object,
		[Parameter(Mandatory = $true)]
		[string]$CommandName,
		$ParametersDefinition,
		[ScriptBlock]$MockWith = {},
		[switch]$AsProperty
	)
	if($Object.mock_functions.ContainsKey("$CommandName")){
		$Object.mock_functions.Remove("$CommandName")
		$Object.PSObject.Properties.Remove("$CommandName")
	}
	
	$Object.mock_functions["$CommandName"] = @()
	
	$scriptBlock = {
		$mock.CallHistory += @{
			BoundParams = $PSBoundParameters;
			Args = $args
		}
		& $mock.MockWith @PSBoundParameters @Args
	}
	
	$parametersString = GenerateParameterDefinition $ParametersDefinition
	
	$scriptBlockString = "
		$parametersString
        `$mock = `$this.mock_functions['$CommandName']
		$scriptBlock
    "

    $cmd = [scriptblock]::Create($scriptBlockString)
	if($AsProperty.isPresent){
		Add-Member -InputObject $Object -MemberType ScriptProperty -Name "$CommandName" -Value $cmd
	}else{
		Add-Member -InputObject $Object -MemberType ScriptMethod -Name "$CommandName" -Value $cmd
	}
	
	$Object.mock_functions["$CommandName"] = @{
		"MockWith"=$MockWith;
		"CallHistory"=@()
	}
}

function Assert-MockObjectCalled {
	param(
		[Parameter(Mandatory = $true)]
		[PSCustomObject]$Object,
		[Parameter(Mandatory = $true)]
		[string]$CommandName,
		[ScriptBlock]$ParameterFilter = { $True },
		[Parameter(Mandatory=$true)]
		[int]$Times = 0,
		[switch]$Exactly
	)
	
	if(!$Object.mock_functions.ContainsKey("$CommandName")){
		throw "You did not declare a mock of the $commandName Command in this object"
	}
	
	$mock = $Object.mock_functions["$CommandName"]

	[array]$qualifiedCalls = $mock.CallHistory | Where-Object {
		$params = @{
            ScriptBlock     = $ParameterFilter
            BoundParameters = $_.BoundParams
            ArgumentList    = $_.Args
        }
		Test-ParameterFilter @params
	}
	
	$count = $qualifiedCalls.Length
	if(!$count) { $count = 0 }
	
	if($count -ne $times -and ($Exactly -or ($times -eq 0))) {
		throw "Expected $commandName to be called $times times exactly but was called $count times"
    } elseif($count -lt $times) {
        throw "Expected ${commandName} to be called at least $times times but was called $count times"
	}
}

function GenerateParameterDefinition {
	param($definition)
	if($definition -is [array]){
		if($definition.length -gt 0){
			$params = $definition | ForEach {
				if($_.Contains('$')){
					$_
				}else{
					'$' + $_
				}
			}
			return "param(" + ($params -join ",") + ")"
		}
	}elseif($definition -is [string]){
		if($definition -contains "param("){
			return "$definition"
		}else{
			return "param($definition)"
		}
	}
}

# Emprunté à "Mock.ps1"

function Test-ParameterFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,

        [System.Collections.IDictionary]
        $BoundParameters,

        [object[]]
        $ArgumentList
    )

    if ($null -eq $BoundParameters)   { $BoundParameters = @{} }
    if ($null -eq $ArgumentList)      { $ArgumentList = @() }

    $paramBlock = Get-ParamBlockFromBoundParameters -BoundParameters $BoundParameters

    $scriptBlockString = "
        $paramBlock
        $ScriptBlock
    "

    $cmd = [scriptblock]::Create($scriptBlockString)

    & $cmd @BoundParameters @ArgumentList
}

function Get-ParamBlockFromBoundParameters {
    param (
        [System.Collections.IDictionary] $BoundParameters
    )

    $params = foreach ($paramName in $BoundParameters.Keys)
    {
        "`${$paramName}"
    }

    $params = $params -join ','

    return "param ($params)"
}

Export-ModuleMember -Function Create-MockObject, MockObject, Assert-MockObjectCalled