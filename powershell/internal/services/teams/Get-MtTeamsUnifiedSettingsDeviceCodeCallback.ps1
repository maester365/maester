function Get-MtTeamsUnifiedSettingsDeviceCodeCallback {
    [CmdletBinding()]
    [OutputType([System.Delegate])]
    param(
        [Parameter(Mandatory)]
        [type]$DeviceCodeType,
        [Parameter(Mandatory)]
        [System.Threading.Tasks.TaskCompletionSource[string]]$MessageSource
    )

    $callbackFactoryType = 'MaesterTeamsDeviceCodeCallbackFactory' -as [type]
    if (-not $callbackFactoryType) {
        $callbackFactorySource = @'
using System;
using System.Linq.Expressions;
using System.Threading.Tasks;

public static class MaesterTeamsDeviceCodeCallbackFactory
{
    public static Delegate Create(Type deviceCodeType, TaskCompletionSource<string> messageSource)
    {
        var deviceCode = Expression.Parameter(deviceCodeType, "deviceCode");
        var message = Expression.Property(deviceCode, "Message");
        var trySetResult = typeof(TaskCompletionSource<string>).GetMethod("TrySetResult", new[] { typeof(string) });
        var captureMessage = Expression.Call(Expression.Constant(messageSource), trySetResult, message);
        var completedTask = Expression.Property(null, typeof(Task).GetProperty("CompletedTask"));
        var callbackBody = Expression.Block(captureMessage, completedTask);
        var callbackType = typeof(Func<,>).MakeGenericType(deviceCodeType, typeof(Task));
        return Expression.Lambda(callbackType, callbackBody, deviceCode).Compile();
    }
}
'@
        $null = Add-Type -TypeDefinition $callbackFactorySource -ErrorAction Stop
        $callbackFactoryType = 'MaesterTeamsDeviceCodeCallbackFactory' -as [type]
    }

    $createMethod = $callbackFactoryType.GetMethod('Create')
    return $createMethod.Invoke($null, @($DeviceCodeType, $MessageSource))
}
