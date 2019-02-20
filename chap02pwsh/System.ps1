function Make-BuiltIn($name, $env) {
    $builtin = New-Object Exp -ArgumentList ([ExpType]::BuiltIn)
    $builtin.value = $name
    $env.Declare($name, $builtin)
}

function Make-Global-Environment() {
    $globEnv = New-Object Environment
    Make-BuiltIn "+" $globEnv
    Make-BuiltIn "-" $globEnv
    Make-BuiltIn "*" $globEnv
    Make-BuiltIn "/" $globEnv
    Make-BuiltIn "=" $globEnv
    Make-BuiltIn "EQUAL?" $globEnv
    Make-BuiltIn "DISPLAY" $globEnv
    Make-BuiltIn "EVAL" $globEnv
    Make-BuiltIn "APPLY" $globEnv
    Make-BuiltIn "READ" $globEnv
    Make-BuiltIn "LOAD" $globEnv
    Make-BuiltIn "CONS" $globEnv
    Make-BuiltIn "CAR" $globEnv
    Make-BuiltIn "CDR" $globEnv
    Make-BuiltIn "LIST" $globEnv
    return $globEnv
}

function Call-BuiltIn($name, $argsExp, $env, $denv) {
    if ($name -eq "APPLY") {
        $applyArgs = (Evaluate $argsExp.cdr.car $env $denv $false)
        return SysApply $argsExp.car $applyArgs

    }
    $args = @()
    $cons = $argsExp
    while ($cons.type -eq "Cons") {
        $val = Evaluate $cons.car $env $denv $false
        $args += $val
        $cons = $cons.cdr
    }
    switch -regex ($name) {
        "\+" {
            return SysPlus $args
        }
        "-" {
            return SysMinus $args
        }
        "\*" {
            return SysMult $args
        }
        "/" {
            return SysDiv $args
        }
        "=" {
            return SysEqNum $args
        }
        "EQUAL?" {
            return SysEqual $args
        }
        "DISPLAY" {
            return SysDisplay $args
        }
        "EVAL" {
            return SysEval $args
        }
        "APPLY" {
            return SysApply $args
        }
        "READ" {
            return SysRead $args $env $denv
        }
        "LOAD" {
            return SysLoad $args $env $denv
        }
        "CONS" {
            return SysCons $args
        }
        "CAR" {
            return SysCAR $args
        }
        "CDR" {
            return SysCDR $args
        }
        "LIST" {
            return SysList $args
        }
    }
}

function SysPlus($a) {
    $result = 0
    foreach ($num in $a) {
        $result += $num.value
    }
    return New-Object Exp -ArgumentList ([ExpType]::Number), $result
}

function SysMinus($a) {
    if ($a.length -eq 0) {
        return New-Object Exp -ArgumentList ([ExpType]::Number), 0
    }
    if ($a[0].type -ne ([ExpType]::Number)) {
        return New-Object Exp -ArgumentList ([ExpType]::Number), 0
    }
    if ($a.length -eq 1) {
        New-Object Exp -ArgumentList ([ExpType]::Number), -$[a].value
    }
    $result = $a[0].value
    $i = 1
    while ($i -lt $a.length) {
        $result -= $a[$i].value
        $i++
    }
    return New-Object Exp -ArgumentList ([ExpType]::Number), $result
}

function SysMult($a) {
    $result = 1
    foreach ($num in $a) {
        $result *= $num.value
    }
    return New-Object Exp -ArgumentList ([ExpType]::Number), $result
}

function SysDiv($a) {
    if ($a.length -eq 0) {
        return New-Object Exp -ArgumentList ([ExpType]::Number), 1
    }
    if ($a[0].type -ne ([ExpType]::Number)) {
        return New-Object Exp -ArgumentList ([ExpType]::Number), 0
    }
    if ($a.length -eq 1) {
        New-Object Exp -ArgumentList ([ExpType]::Number), 0
    }
    $result = $a[0].value
    $i = 1
    while ($i -lt $a.length) {
        $result = [math]::floor($result / $a[$i].value)
        $i++
    }
    return New-Object Exp -ArgumentList ([ExpType]::Number), $result
}

function SysDisplay($a) {
    $e = New-Object Exp -ArgumentList ([ExpType]::Symbol), "NIL"
    foreach ($exp in $a) {
        $e = $exp
        Write-Host [SYS] $exp
    }
    return $e
}

function IsEqual($exp1, $exp2) {
    if ($exp1.type -ne $exp2.type) {
        return $false
    }
    if ($exp1.type -eq ([ExpType]::Cons)) {
        return (IsEqual $exp1.car $exp2.car) -and (IsEqual $exp1.cdr $exp2.cdr)
    }
    return $exp1.value -eq $exp2.value
}

function SysEqNum($a) {
    $val = $a[0].type -eq ([ExpType]::Number) -and $a[0].type -eq $a[1].type -and $a[0].value -eq $a[1].value
    return New-Object Exp -ArgumentList ([ExpType]::Boolean), $val
}

function SysEqual($a) {
    return New-Object Exp -ArgumentList ([ExpType]::Boolean), (IsEqual $a[0] $a[1])
}

function SysEval($a) {
    return Evaluate $a[0] (Make-Global-Environment) (New-Object Environment) $false
}

function SysApply($funExp, $argsExp) {
    $function = Evaluate $funExp $env $denv $false
    $env = Make-Global-Environment
    $denv = New-Object Environment
    if ($function.type -eq "BuiltIn") {
        return Call-BuiltIn $function $argsExp $env $denv $false
    } elseif ($function.type -eq "Function") {
        return Invoke $function $argsExp $env $denv $false
    }
    return $null
}

function SysRead($a, $env, $denv) {
    if ($a.length -eq 1) {
        $msg = $a[0].value
    } else {
        $msg = ">"
    }
    $text = Read-Host $msg
    $tokens = Get-Tokens $text
    $exps = Parse-Tokens $tokens
    $exps | ForEach-Object {
        try {
            $exp = Evaluate $_ $env $denv $false
        } catch [EvaluatorException] {
            Write-Output ("Exception in SysLoad: " + $($_.Exception.msg))
        }
    }
    return $exp
}

function SysLoad($a, $env, $denv) {
    $path = $a[0].value
    $text = [System.IO.File]::ReadAllText( (Resolve-Path $path) )
    $tokens = Get-Tokens $text
    $exps = Parse-Tokens $tokens
    $exps | ForEach-Object {
        try {
            $exp = Evaluate $_ $env $denv $false
        } catch [EvaluatorException] {
            Write-Output ("Exception in SysLoad: " + $($_.Exception.msg))
        }
    }
    return $exp
}

function SysCons($a) {
    return New-Object Exp -ArgumentList ([ExpType]::Cons), $a[0], $a[1]
}

function SysCAR($a) {
    return $a[0].car
}

function SysCDR($a) {
    return $a[0].cdr
}

function SysList($a) {
    return List-To-Cons($a)
}
