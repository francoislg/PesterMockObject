# MockObject module for Pester

## What is this

Lets you create a mock object to insert into another module.

## Why would I use this

If you have a module that must be imported with "-asCustomObject", it can't be mocked by the current Pester framework.

This module allows you to create a mocked object and use Assert on it to verify if the method has been called a number of times with specific parameters.

## How do I use this

Consider :
* A module "ObjModule" that must be imported as a custom object, that has "MyMethod" command
* Another module "SomeModule" that has a method "Execute" that needs a custom object and calls its method "MyMethod"

### Create a mock object

```Powershell
$myObject = Create-MockObject
```

### Insert it in a dependency

```Powershell
Import-Module "SomeModule" -ArgumentList $myObject
```

### Do some testing

```Powershell
Describe "SomeTest" {
    MockObject $myObject -CommandName "MyMethod" -MockWith {
        return 1
    }
    Context "When Calling Execute" {
        Execute "Something"

        It "Should call MyMethod" {
            Assert-MockObjectCalled $myObject -CommandName "MyMethod" -Times 1 -Exactly
        }
    }
}
```

### Or with a ParameterDefinition and ParameterFilter

```Powershell
Describe "SomeTest" {
    MockObject $myObject -CommandName "MyMethod" -MockWith {
        param($myParam)
        return 1
    }  -ParametersDefinition @("myParam")
    Context "When Calling Execute" {
        Execute "Something"

        It "Should call MyMethod" {
            Assert-MockObjectCalled $myObject -ParameterFilter {
                $myParam -eq "Something"
                } -CommandName "MyMethod" -Times 1 -Exactly
        }
    }
}
```

### Or as property

```Powershell
Describe "SomeTest" {
    MockObject $myObject -CommandName "myProperty" -MockWith {
        return 1
    } -AsProperty
    Context "When Calling Execute" {
        Execute "ReadProperty"

        It "Should ask for property" {
            Assert-MockObjectCalled $myObject -CommandName "myProperty" -Times 1 -Exactly
        }
    }
}
```

In this example, $myObject.myProperty is a mocked variable.

## ParameterDefinition

When mocking, this parameter lets you define bound parameters. This allows you to mock parameters name and pass them to your mocked function.

### Example

```Powershell
MockObject $myObject -CommandName "MyMethod" -MockWith {
    param($myParam)
    return 1
}  -ParametersDefinition @("myParam")
```

When $myObject.MyMethod("1") will be called, the first value will be bound to $myParam ("1" in this case)

All the other parameters will be passed as $args. $myObject.MyMethod("1", "2") will bind $myParam to "1", and $args[0] to "2"

## Things to know / Limitations

### Execution counter is set with MockObject

This means :

* If you define your MockObject outside of a Describe, each Method will be mocked for the whole Execution
* If you want to reset the MockObject execution counter, you have to call MockObject again on that command

### It's better with bound parameters

It's way easier to read, and allows better control when using with -ParameterFilter in a Assert-MockObjectCalled

### The object created is not based off an existing object

Where Pester needs a real method to exists in a module before mocking it, MockObject doesn't base itself on an existing object.

This means you have to mock every method your module uses.

You can probably rewrite the call to the mock if you need to (not tested)

## Available Cmdlets

### Create-MockObject

No additional parameter.

### MockObject

#### -Object

The object to add a method to

#### -CommandName

The name of the command

#### -ParametersDefinition

Can be an array or string which defines what parameters are passed to the mock.

Allows you to define Named Parameters for the mock

#### -MockWith

Scriptblock to execute when called.

$this should be bound to the object. So the following example will work

``` Powershell
MockObject $mock -CommandName "Test" -MockWith {
	return "Value"
} -AsProperty

MockObject $mock -CommandName "Second" -MockWith {
	return "Second " + $this.Test
} -AsProperty
```

#### -AsProperty

Define the command as a property.

Which means your Mocked Object will have a property that will execute the scriptblock when called.

Allows you to define values like "$myObject.value" instead of "$myObject.GetValue()"

### Assert-MockObjectCalled

#### -Object

The object to verify the called method

#### -CommandName

The name of the command

#### -ParameterFilter

Optional Scriptblock. Only counts the values that matches the Scriptblock, similar to how Pester's Assert-MockCalled works.

#### -Times

Number of times the command must at least be called (Like Assert-MockCalled)

#### -Exactly

If present, the command must be called exactly X times (Like Assert-MockCalled)
