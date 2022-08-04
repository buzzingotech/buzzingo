using namespace Windows.Storage
using namespace Windows.Graphics.Imaging

<#
.Synopsis
   Runs Windows 10 OCR on an image.
.DESCRIPTION
   Takes a path to an image file, with some text on it.
   Runs Windows 10 OCR against the image.
   Returns an [OcrResult], hopefully with a .Text property containing the text
.EXAMPLE
   $result = .\Get-Win10OcrTextFromImage.ps1 -Path 'c:\test.bmp'
   $result.Text
#>
[CmdletBinding()]
Param
(
    # Path to an image file
    [Parameter(Mandatory=$true, 
                ValueFromPipeline=$true,
                ValueFromPipelineByPropertyName=$true, 
                Position=0,
                HelpMessage='Path to an image file, to run OCR on')]
    [ValidateNotNullOrEmpty()]
    $Path
)

Begin {
    # Add the WinRT assembly, and load the appropriate WinRT types
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $null = [Windows.Storage.StorageFile,                Windows.Storage,         ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine,                Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Foundation.IAsyncOperation`1,       Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap,    Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    
    
    # [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    

    # PowerShell doesn't have built-in support for Async operations, 
    # but all the WinRT methods are Async.
    # This function wraps a way to call those methods, and wait for their results.
    $getAwaiterBaseMethod = [WindowsRuntimeSystemExtensions].GetMember('GetAwaiter').
                                Where({
                                        $PSItem.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
                                    }, 'First')[0]

    Function Await {
        param($AsyncTask, $ResultType)

        $getAwaiterBaseMethod.
            MakeGenericMethod($ResultType).
            Invoke($null, @($AsyncTask)).
            GetResult()
    }
}

Process
{
    foreach ($p in $Path)
    {
      
        # From MSDN, the necessary steps to load an image are:
        # Call the OpenAsync method of the StorageFile object to get a random access stream containing the image data.
        # Call the static method BitmapDecoder.CreateAsync to get an instance of the BitmapDecoder class for the specified stream. 
        # Call GetSoftwareBitmapAsync to get a SoftwareBitmap object containing the image.
        #
        # https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/imaging#save-a-softwarebitmap-to-a-file-with-bitmapencoder

        # .Net method needs a full path, or at least might not have the same relative path root as PowerShell
        $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
        
        $params = @{ 
            AsyncTask  = [StorageFile]::GetFileFromPathAsync($p)
            ResultType = [StorageFile]
        }
        $storageFile = Await @params


        $params = @{ 
            AsyncTask  = $storageFile.OpenAsync([FileAccessMode]::Read)
            ResultType = [Streams.IRandomAccessStream]
        }
        $fileStream = Await @params


        $params = @{
            AsyncTask  = [BitmapDecoder]::CreateAsync($fileStream)
            ResultType = [BitmapDecoder]
        }
        $bitmapDecoder = Await @params


        $params = @{ 
            AsyncTask = $bitmapDecoder.GetSoftwareBitmapAsync()
            ResultType = [SoftwareBitmap]
        }
        $softwareBitmap = Await @params

        # Run the OCR
        Await $ocrEngine.RecognizeAsync($softwareBitmap) ([Windows.Media.Ocr.OcrResult])

    }
}
# SIG # Begin signature block
# MIIbrQYJKoZIhvcNAQcCoIIbnjCCG5oCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUgEVbmvfdH/G3HGuV3CJJmF2B
# z32gghYrMIIC9jCCAd6gAwIBAgIQGXer1xZoWr1JRQKSK1FuuzANBgkqhkiG9w0B
# AQsFADATMREwDwYDVQQDDAhCdXp6aW5nbzAeFw0yMjA4MDQxNTU2MzBaFw0zMjA4
# MDQxNjA2MzBaMBMxETAPBgNVBAMMCEJ1enppbmdvMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA6ErDIyvg3doQUuEw/BgYVwMB/IUskkoR/w8l3XQTurpI
# e8SudFlFyA7tAKCv8gw4/+AgYXhnqyjY/cjSNWFqlHmX+YDN1L6kT1S6a11WHUhB
# 5PZ5let0Li3gur/XGL+AKBoKEhES0MglET00Ne6iJNy2/LqOb4WVn/6HemqJCV/2
# /erzBvQklOA3IF9uvuimvI2MX+cqrhd79KxHBj/fEwYhHfqUCJypMWuhS33UP3TQ
# k/sfP5oQPvgcTyZn68orbUxyGX105JDrwAWRJtHy1cjJLANL7zE62Oop70aX83yh
# ZOHKba+Ohz3Vr5aezRDIuXJVptfP8TUpkCo3GZgP+QIDAQABo0YwRDAOBgNVHQ8B
# Af8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFPVv6kpYDow4
# UDFkG6L94EFM2A3LMA0GCSqGSIb3DQEBCwUAA4IBAQCmxXPDbc/TgrQa9FhkYXID
# nGomAfg3xe4yBrOQm97jL4gadyBd+vJYy/7AoqxVh3GM+faju41oY8zzVftsmmYZ
# xNa0JXkp97cCpHgtktmJW8I20igDKPTa5VnxzgfGkOrDVNOsWGP1u3y58eN0b6J+
# V76Hrt2Ub6LYlQSWZcs8Mz6l113vK0yC3wAvb5a1fxApqeI4VDCWdw2MlCwjVe4t
# 214iv57SPNG6/9sOzcaomGAV5Ae6M3uTv+A3+YEfNgt8sep4l7dwssxoEGlX4/xg
# 0A0EDUIkUEspBOAFpz6LewSLoFrPOeBoN/2uoJTA88SXVx8hwoJYp+zPMaebugwg
# MIIFsTCCBJmgAwIBAgIQASQK+x44C4oW8UtxnfTTwDANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwNjA5MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBXjCCAVowDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHkG
# CCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# IAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBDAUA
# A4IBAQCaFgKlAe+B+w20WLJ4ragjGdlzN9pgnlHXy/gvQLmjH3xATjM+kDzniQF1
# hehiex1W4HG63l7GN7x5XGIATfhJelFNBjLzxdIAKicg6okuFTngLD74dXwsgkFh
# NQ8j0O01ldKIlSlDy+CmWBB8U46fRckgNxTA7Rm6fnc50lSWx6YR3zQz9nVSQksc
# nY2W1ZVsRxIUJF8mQfoaRr3esOWRRwOsGAjLy9tmiX8rnGW/vjdOvi3znUrDzMxH
# XsiVla3Ry7sqBiD5P3LqNutFcpJ6KXsUAzz7TdZIcXoQEYoIdM1sGwRc0oqVA3ZR
# UFPWLvdKRsOuECxxTLCHtic3RGBEMIIGrjCCBJagAwIBAgIQBzY3tyRUfNhHrP0o
# ZipeWzANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhE
# aWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIy
# MjM1OTU5WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4x
# OzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGlt
# ZVN0YW1waW5nIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1
# BkmzwT1ySVFVxyUDxPKRN6mXUaHW0oPRnkyibaCwzIP5WvYRoUQVQl+kiPNo+n3z
# nIkLf50fng8zH1ATCyZzlm34V6gCff1DtITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZ
# Kz5C3GeO6lE98NZW1OcoLevTsbV15x8GZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald6
# 8Dd5n12sy+iEZLRS8nZH92GDGd1ftFQLIWhuNyG7QKxfst5Kfc71ORJn7w6lY2zk
# psUdzTYNXNXmG6jBZHRAp8ByxbpOH7G1WE15/tePc5OsLDnipUjW8LAxE6lXKZYn
# LvWHpo9OdhVVJnCYJn+gGkcgQ+NDY4B7dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIq
# x5K/oN7jPqJz+ucfWmyU8lKVEStYdEAoq3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOd
# OqPVA+C/8KI8ykLcGEh/FDTP0kyr75s9/g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJ
# TYsg0ixXNXkrqPNFYLwjjVj33GHek/45wPmyMKVM1+mYSlg+0wOI/rOP015LdhJR
# k8mMDDtbiiKowSYI+RQQEgN9XyO7ZONj4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEo
# AA6EVO7O6V3IXjASvUaetdN2udIOa5kM0jO0zbECAwEAAaOCAV0wggFZMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLoW2W1NhS9zKXaaL3WMaiCPnshvMB8G
# A1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjAT
# BgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYD
# VR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0
# VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9
# bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQB9WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0T
# zzBTzr8Y+8dQXeJLKftwig2qKWn8acHPHQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYS
# lm/EUExiHQwIgqgWvalWzxVzjQEiJc6VaT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaq
# T5Fmniye4Iqs5f2MvGQmh2ySvZ180HAKfO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl
# 2szwcqMj+sAngkSumScbqyQeJsG33irr9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1y
# r8THwcFqcdnGE4AJxLafzYeHJLtPo0m5d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05
# et3/JWOZJyw9P2un8WbDQc1PtkCbISFA0LcTJM3cHXg65J6t5TRxktcma+Q4c6um
# AU+9Pzt4rUyt+8SVe+0KXzM5h0F4ejjpnOHdI/0dKNPH+ejxmF/7K9h+8kaddSwe
# Jywm228Vex4Ziza4k9Tm8heZWcpw8De/mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr
# 7ZVBtzrVFZgxtGIJDwq9gdkT/r+k0fNX2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYC
# JtnwZXZCpimHCUcr5n8apIUP/JiW9lVUKx+A+sDyDivl1vupL0QVSucTDh3bNzga
# oSv27dZ8/DCCBsYwggSuoAMCAQICEAp6SoieyZlCkAZjOE2Gl50wDQYJKoZIhvcN
# AQELBQAwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTsw
# OQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVT
# dGFtcGluZyBDQTAeFw0yMjAzMjkwMDAwMDBaFw0zMzAzMTQyMzU5NTlaMEwxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEkMCIGA1UEAxMbRGln
# aUNlcnQgVGltZXN0YW1wIDIwMjIgLSAyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAuSqWI6ZcvF/WSfAVghj0M+7MXGzj4CUu0jHkPECu+6vE43hdflw2
# 6vUljUOjges4Y/k8iGnePNIwUQ0xB7pGbumjS0joiUF/DbLW+YTxmD4LvwqEEnFs
# oWImAdPOw2z9rDt+3Cocqb0wxhbY2rzrsvGD0Z/NCcW5QWpFQiNBWvhg02UsPn5e
# vZan8Pyx9PQoz0J5HzvHkwdoaOVENFJfD1De1FksRHTAMkcZW+KYLo/Qyj//xmfP
# PJOVToTpdhiYmREUxSsMoDPbTSSF6IKU4S8D7n+FAsmG4dUYFLcERfPgOL2ivXpx
# mOwV5/0u7NKbAIqsHY07gGj+0FmYJs7g7a5/KC7CnuALS8gI0TK7g/ojPNn/0oy7
# 90Mj3+fDWgVifnAs5SuyPWPqyK6BIGtDich+X7Aa3Rm9n3RBCq+5jgnTdKEvsFR2
# wZBPlOyGYf/bES+SAzDOMLeLD11Es0MdI1DNkdcvnfv8zbHBp8QOxO9APhk6AtQx
# qWmgSfl14ZvoaORqDI/r5LEhe4ZnWH5/H+gr5BSyFtaBocraMJBr7m91wLA2JrII
# O/+9vn9sExjfxm2keUmti39hhwVo99Rw40KV6J67m0uy4rZBPeevpxooya1hsKBB
# GBlO7UebYZXtPgthWuo+epiSUc0/yUTngIspQnL3ebLdhOon7v59emsCAwEAAaOC
# AYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATAf
# BgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57IbzAdBgNVHQ4EFgQUjWS3iSH+
# VlhEhGGn6m8cNo/drw0wWgYDVR0fBFMwUTBPoE2gS4ZJaHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVTdGFt
# cGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcwAoZMaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNBNDA5NlNIQTI1NlRpbWVT
# dGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAgEADS0jdKbR9fjqS5k/AeT2
# DOSvFp3Zs4yXgimcQ28BLas4tXARv4QZiz9d5YZPvpM63io5WjlO2IRZpbwbmKro
# bO/RSGkZOFvPiTkdcHDZTt8jImzV3/ZZy6HC6kx2yqHcoSuWuJtVqRprfdH1AglP
# gtalc4jEmIDf7kmVt7PMxafuDuHvHjiKn+8RyTFKWLbfOHzL+lz35FO/bgp8ftfe
# mNUpZYkPopzAZfQBImXH6l50pls1klB89Bemh2RPPkaJFmMga8vye9A140pwSKm2
# 5x1gvQQiFSVwBnKpRDtpRxHT7unHoD5PELkwNuTzqmkJqIt+ZKJllBH7bjLx9bs4
# rc3AkxHVMnhKSzcqTPNc3LaFwLtwMFV41pj+VG1/calIGnjdRncuG3rAM4r4SiiM
# Eqhzzy350yPynhngDZQooOvbGlGglYKOKGukzp123qlzqkhqWUOuX+r4DwZCnd8G
# aJb+KqB0W2Nm3mssuHiqTXBt8CzxBxV+NbTmtQyimaXXFWs1DoXW4CzM4AwkuHxS
# Cx6ZfO/IyMWMWGmvqz3hz8x9Fa4Uv4px38qXsdhH6hyF4EVOEhwUKVjMb9N/y77B
# DkpvIJyu2XMyWQjnLZKhGhH+MpimXSuX4IvTnMxttQ2uR2M4RxdbbxPaahBuH0m3
# RFu0CAqHWlkEdhGhp3cCExwxggTsMIIE6AIBATAnMBMxETAPBgNVBAMMCEJ1enpp
# bmdvAhAZd6vXFmhavUlFApIrUW67MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQZTJD3EZ4XnqMN
# FinRkYio8Vq6PDANBgkqhkiG9w0BAQEFAASCAQAIwYx5KAf/b2mfbdzYPaP3zbwd
# SEi0n4F6Rre2YzOTQbF7sUaMmL1bOtUxYcaXLazP9t8RoxP2IaLM9xebsB3fw6ct
# qntaI+F/rDXNKm0Ozot6j+sCf6nwTa3op3+/OI7XeY9JKbhniUhlTD9GO9QAEbFG
# WFBrlZoU3sQhwi1dmqjtntRarYFYheCeQFUKagkU2NklpgMTx16dhvKpS3F+2mqO
# 0pEaqsesTmqcc42Kg26Z6ox3Uyv+4EpvgWqW+dSMvbBFULhKpMGHye1xYOzoZgzs
# swBWCOkAYwimcTGolvknYPkDIf6DlKHXJcFpb1yQvIlToC5ES8Ha4BXUYlBeoYID
# IDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQCnpKiJ7JmUKQBmM4
# TYaXnTANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTIyMDgwNDE3MDgyM1owLwYJKoZIhvcNAQkEMSIEINUP
# +yA8w1L+cFwXy342e7/MEX/7+zFv8eWL7c+yroTTMA0GCSqGSIb3DQEBAQUABIIC
# AIId8X/YUylcouVgR5X8YMkeOReBx7K43EG4DM0LBT6oUQuft7PCpkSA4RkVwXwY
# hXiWsiNNCgZCMrnFcdGV+Q2GeRzBx+eF9i65k4nbTzTPd/+08iRKMuMEqdMaIRlq
# BKOPva26ShN3Kr/0cNESz+clbnVm0ozxmnl/9UvHS2pvF+ZT9W70lK5v8sIxpoKx
# jDGlHHLONN4DqgrQWsmwuD8QnlYYrXFQA2CNZrUXnou5r988Fl9ZAuFru8NAr5pd
# peV/h7IBuOkAeGnhivzS4qfdhEItvJkB0Lb2omW2mIoCHimGXJiDwu5SF8momsnM
# 9lQxphURVaozYd6ytqm/nEZqzAiwdg4bsX4jYSqnAigloUIoX36Bp3wK757zhMLh
# 6saRxdkwrwXHEKMVSWmx3Yixroby7LIRPI2635T2HT40N18kKCYfF1i2IJgi7ujq
# la6IRU+rzC+qdrwunaP/C9xlPQvy6cqzxqbO5l6ojLAKXCP20275hOclgj1TfmD3
# QREbxM2GO47AWe1Y6U2dE+p+Z4xq3NLqJbBT6E8OcNyLtiXsE+J5cgVfSab+5PPG
# 7kwzakCvJ+1pHgJF/pCiOabEmI5yEFLE+vezyHSoyxVNkE1IAVubj2wWu1yfYNSy
# XAp7pKyO6gEZIGFLLU9ECZViY1rNNedwVJSnX14D6ewX
# SIG # End signature block
