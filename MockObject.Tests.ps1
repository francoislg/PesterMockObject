$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.ps1", ".psm1")
Import-Module "$here\$sut" -Force

Describe "Create-MockObject" {
	Context "Create a mock" {
		$mock = Create-MockObject
	
		It "Should create empty object" {
			$mock.GetType() | Should Be "System.Management.Automation.PSCustomObject"
		}
	}
}

Describe "MockObject" {
	$mock = Create-MockObject

	Context "Add a mock" {
		MockObject $mock -CommandName "Test" -MockWith {}
	
		It "Should add the method" {
			$mock.Test | Should Be "System.Object Test();"
		}
	}
	
	Context "Add a mock as property" {
		MockObject $mock -CommandName "Test" -MockWith {
			return "Value"
		} -AsProperty
	
		It "Should return property value" {
			$mock.Test | Should Be "Value"
		}
	}
	
	Context "Add mock that uses another property" {
		MockObject $mock -CommandName "Test" -MockWith {
			return "Value"
		} -AsProperty
		
		MockObject $mock -CommandName "Second" -MockWith {
			return "Second " + $this.Test
		} -AsProperty
	
		It "Should return property computed from both values" {
			$mock.Second | Should Be "Second Value"
		}
	}
	
	Context "Call the mock and return value" {
		MockObject $mock -CommandName "Test" -MockWith {
			Write-Output "OK"
		}
	
		It "Should return value in mock" {
			$mock.Test() | Should Be "OK"
		}
	}
	
	Context "Call the mock and return arguments" {
		MockObject $mock -CommandName "Test" -MockWith {
			return $args
		}
		
		$test = 1
		$value = 2
		
		$result = $mock.Test($test,$value)
	
		It "Should return same values" {
			$result[0] | Should Be $test
			$result[1] | Should Be $value
		}
	}
	
	Context "Mock same function twice" {
		MockObject $mock -CommandName "Test" -MockWith {
			Write-Output "Invalid"
		}
		MockObject $mock -CommandName "Test" -MockWith {
			Write-Output "OK"
		}
		
		It "Should overwrite previous mock" {
			$mock.Test() | Should Be "OK"
		}
	}
	
	Context "Simple mock with parameters definition" {
		MockObject $mock -CommandName "Test" -ParametersDefinition @("Test") -MockWith {}
		Set-Variable -Scope Global -Name "VALUE" -Value "OMG"
		
		$mock.Test($VALUE)
		
		It "Should Assert defined parameter with value given" {
			Assert-MockObjectCalled $mock -CommandName "Test" -ParameterFilter {
				$test -eq $VALUE
			} -Times 1 -Exactly
		}
		It "Should not assert other parameters with value given" {
			Assert-MockObjectCalled $mock -CommandName "Test" -ParameterFilter {
				$anything -eq $VALUE
			} -Times 0
		}
	}
	
	Context "Simple mock with strongly typed parameters definition" {
		MockObject $mock -CommandName "Test" -ParametersDefinition @('[array]$Test') -MockWith {}
		Set-Variable -Scope Global -Name "VALUE" -Value "OMG"
		
		$mock.Test(@($VALUE))
		
		It "Should assert with strongly typed parameter" {
			Assert-MockObjectCalled $mock -CommandName "Test" -ParameterFilter {
				$test -is [array]
			} -Times 1 -Exactly
		}
	}
	
	Context "Mock with parameters definition and parameters in MockWith" {
		Set-Variable -Scope Global -Name "FIRSTPARAMNAME" -Value "Test"
		Set-Variable -Scope Global -Name "VALUE" -Value "OMG"
		Set-Variable -Scope Global -Name "SECONDVALUE" -Value "SECOND"
		Set-Variable -Scope Global -Name "SECONDPARAMNAME" -Value "SecondParam"
		MockObject $mock -CommandName "Test" -ParametersDefinition @("$FIRSTPARAMNAME","$SECONDPARAMNAME") -MockWith {
			param($test)
			return @{
				"$FIRSTPARAMNAME"=$test;
				"args"=$args
			}
		}
		
		$result = $mock.Test($VALUE, $SECONDVALUE)
		
		It "Should have valid bound parameters" {
			$result."$FIRSTPARAMNAME" | Should Be $VALUE
		}
		It "Should have valid unbound parameters (args)" {
			$result.args[0] | Should Match "$SECONDPARAMNAME"
			$result.args[1] | Should Be $SECONDVALUE
		}
	}
}

Describe "Assert-MockObjectCalled" {
	$mock = Create-MockObject
	
	Context "MockObject called in Context" {
		MockObject $mock -CommandName "Test" -MockWith {}
		$mock.Test()
		
		It "Should Assert one time" {
			Assert-MockObjectCalled $mock -CommandName "Test" -Times 1 -Exactly
		}
	}
	
	Context "MockObject called in Context and in It" {
		MockObject $mock -CommandName "Test" -MockWith {}
		$mock.Test()
		
		It "Should Assert two times" {
			$mock.Test()
			Assert-MockObjectCalled $mock -CommandName "Test" -Times 2 -Exactly
		}
	}
	
	MockObject $mock -CommandName "Test" -MockWith {}
	$mock.Test()
	
	Context "MockObject called in Describe and in Context" {
		$mock.Test()
		
		It "Should Assert two times" {
			Assert-MockObjectCalled $mock -CommandName "Test" -Times 2 -Exactly
		}
	}
}