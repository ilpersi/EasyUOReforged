unit mainiconsdata;

{
  Port addition: the main window's toolbar and menu icons, written by make_toolbar_icons.py (in
  this folder): do not edit by hand, run it again. They are in the MENU Designer's style, from
  Lazarus' 16x16 outline set (general_purpose) by Roland Hahn, CC0 1.0 (no restrictions), as
  Lazarus' images/copyright.txt and images/general_purpose/lazarus_general_purpose_images.txt
  say. The script draws what the set does not have. In ImageIndex order, see mainicons.pas.

     0 New        general_purpose Add_01_16
     1 Open       general_purpose Folder_01_16
     2 Save       general_purpose Save_03_16
     3 Cut        general_purpose Cut_02_16
     4 Copy       general_purpose Copy_02_16
     5 Paste      general_purpose Paste_02_16
     6 Find       general_purpose Search_03_16
     7 Replace    general_purpose Replace_03_16
     8 Start      general_purpose Play_01_16, green
     9 Pause      general_purpose Pause_01_16, orange
    10 Stop       general_purpose Stop_01_16, red
    11 StopAll    drawn: two stop rings, red
    12 Help       general_purpose Help_03_16
    13 Website    drawn: a globe
    14 Reopen     general_purpose Folder_01_16 with a drawn clock
    15 SaveAll    drawn: a floppy with a second one behind it
    16 Close      general_purpose Remove_02_16
    17 NewClient  general_purpose Window_02_16 with ovl_Plus_06_16
    18 SwapClient general_purpose Window_02_16 with drawn arrows
    19 Format     general_purpose Align_05_16
}

{$mode delphi}{$H+}

interface

const
  ToolbarIcons : array[0..19] of String = (
    // 0 New
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAJ5JREFUOI29kcEJg0AQRf+K2ExM' +
    'B+biIQ2EbIuBqSBHwS1hUoQ1eJgcNoIZZsKqkH+c/3n8/RuwiFjgSTCjkivu58HN/AQQC4gn0KvX' +
    'VuUTtcINkIeGlAPiKVmQuhhALMDnlSJPAI0R2ALL2rCBrT8CiEcQj/pcPiLQHWuwVmxDWYNcuVO3' +
    '5QcSYns5PKJF9n0js6/BClR7xpfyaMmy3gqnPad0fErOAAAAAElFTkSuQmCC',
    // 1 Open
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAANVJREFUOI3FkzFqAmEQhb8ZV2Kp' +
    'QVKk3hXUG3gN42FSSaqcIUeIpvYUlirCv15AxUgqA67PxnTB8LtFHkwz8L0HjxmTRBl5KRpIAOxj' +
    'MUR6Bu4u+2/MXvXUefnLwCRh4/kB7FGDzg7Axot70AqoX2H3GnQbSILRTJKImR+mdAfGaLYBmjfy' +
    '2wT4wr2nfjtEJb8vW3gxcSBQkEVn+zEDQoKRQxFvACmQO1IAS6NxswyUO5Bf3OIkUlQJzikJcEMH' +
    'kFEhGG/TKo3amutX95v2fB4e7N+/8QwA2G2c/wql3wAAAABJRU5ErkJggg==',
    // 2 Save
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAALVJREFUOI3tkzEKwkAQRd8kC7bx' +
    'BqmT2ygR7LxJ8CZ2SgKexoCduYGpw8axiEoCK6vB0t/NLLz5w98RitMViPhOR5C1ZklrgEizVJ4v' +
    'UlY6qg/nmMBuuJkdYXcBmYEWoHtgGXhnGRsjkmNsDKBZ0oKsgAWAH+BQD+nlB1hTo7rFmtpp0NFr' +
    'pKz0VYUAAmGXA40XoFk697pyAaSsPo2zGQ4ZOhjF+U6j9ZiYwh/wY4BMPGd4/Ic7ySw5+eif6mkA' +
    'AAAASUVORK5CYII=',
    // 3 Cut
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAdNJREFUOI2Nks1L1FEYhZ9zVSpt' +
    'NmIbITChReMshPoHzBaBu8bBXVFDRkNftIpWQlCDuIhwZc0iQ7LBTW1s7abVLKrfiC6qVRFMCBGV' +
    'WHNPC9NsZkAvXLj3vec8nPflYpudmwkHyski5erJ7dqzZIhyssiEQ6M+0LjSyTDoK/jydk0UgG8M' +
    'LA81ypsBMIg1C+7U/Gqv5ld7wZ3Is8Bgo7i9yS59h3oKUSL8zv9NUCIqheKP3RPUwxLWKXq+vEBx' +
    'BMWRzbOGCWFpV4DHjiWIfmqpLhwqxLaEWqoL4lFn09W9zADEYziQp71+j+BDeN9FzMNW0taAtfWn' +
    '4Czda58RJrSNoVDeM8Djx38Bn6j1nAPNgd87l97YM0AzlQ7kPkwe8xxzWDOVjpZa2/8u5eQ20jVg' +
    'Hekl0T/BHyCkkU8D+0H3nUsXmwBaWL6EPQm+ApwFnQBWkTawB1F4BXEOM4246dGBR/+3YF9FKjqX' +
    'eYLCNHCQ4HHq8TyokxinPTowi13Evt5iBuonOtmExQx4xdnMG49l3oFXCMpsOkIV1Lfl2vGV42vE' +
    'BZWr3Ui3wDd2wB9gT2mh+hFzBvS2OUEIBVA/ooi441ymtN1dLj0DuouZBI4Aha23P9l50VkMe6C4' +
    'AAAAAElFTkSuQmCC',
    // 4 Copy
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAJRJREFUOI3NkjsSgzAMRFcejpIK' +
    'nyQtMw5nzFAwVJyELsdI46TYdIA/InaGIq/0yCvtSkISMTIs6ePGBMiNrn0BQKNV0VnJC5MAR5kf' +
    'Ha8Xbw46KZgekDee/n44gQ59MBXJKs/rx2EhnZV1glLPcU1BBqHnmIIMmHQtFtjb0nL6YY0nC1Td' +
    'Qc5GlUBu1X+UwZdzVvkAkL1EXREUKksAAAAASUVORK5CYII=',
    // 5 Paste
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAMFJREFUOI3Nkz0OAiEQhd8Yj2Jh' +
    'ZOMJPIHbSoxXXLTE2isY2S1MvIalz2p/YIFVK19FmOHNxwwISbQSU18BrNGLgNypV0skJKhuFpBt' +
    'd0Ir8RJM3VcAz9RF6VtUjiRB0lvH9mLxeUD0EFO/AAwo6FL4AHwDarXIJcc0+yY57M+IIJTfQE9P' +
    'CEvuikvWIFVVTLMBcRLTHCYNYiTUSuTo9iBsdDS5sYXxnwiGV/vIINaHVn9BIDZXYZJu+J1HwfRD' +
    '6vQG+LiiH/bEUjQAAAAASUVORK5CYII=',
    // 6 Find
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAYJJREFUOI2V07FLW1EUx/HvuVQ0' +
    'FHTQSq2LOHQQdbeYQWlNoThoeYObY+niv2AmBdHR/gnCezSCtEM6ZGihGdrNRysOulnRuARKWo33' +
    '52AMPjUPPXCXyzmfc+/lXJPE9bDC9iDeTeLpxnGC8yXNjuzRIuwKsI3dHh6dfQDGMYrAIfAUkQO+' +
    'UW97r7nnlTuBRvF3jAKq5hWM1ZoJUTmDOhcxZqi3vbiFSIIwDgnjJUm0WkTxMmEc3tx3VtgeBLL8' +
    'fZxvdc/LTtU8kG3kN8Ph3SRGUfMD/1Lrg7EaRpFzm0gC2BO8DlK7X4XXAeZ6bwA6xtmzewFYP/JH' +
    'ScD5EiJnUTmTWhqVMxhT4EsJQLMje5i+os7F9OZda6CfCkb3E9uSsM2dburn5ZZzQNcq6B3oFHir' +
    'YPhzAoDmJK4DWcQXHH/w9GHkQD/AXgHtwH9QE7HUv2CqgC8pGN236Ndr0CbQAZyCBQqGtm4B6Q8Z' +
    'vwH7eO0k0w8C7kA+PRgAsPD3S8wvILdyAVAq1wSQrvtsAAAAAElFTkSuQmCC',
    // 7 Replace
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAPRJREFUOI2lkLFKA0EURc9d1EYU' +
    '23yBsLEwnYWtoEKiaAK2foJ1yuRLRBB2NwhBsbRIinQ22QFbvyAiFsHFZyEMBMTdjKec9+Zw35WZ' +
    '8R+isgVl7khJ3gwWYNwihkpdX6DlBeIKKMC6ZO5aqVtbGFfpQOn0AJQBm8ATq59ndro7+/En0xGw' +
    'X2pZJAcdWyd+LT/hd+pgEw1co9IJfxGawLOigWvwZQ9ALeD/OLLz+Bm0B+QhCXwHGr5sMC8S4BD4' +
    'QHZh7Z37MoHvwFrb76ATpBtgHdOdMndZOYF/AJG6HlgX9GadeGspgR8keZNIhbXjxyBBVb4BhkxX' +
    '0L1etboAAAAASUVORK5CYII=',
    // 8 Start
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABTElEQVR42pXTO0tdQRQF4O9oEOx8' +
    'NIIWuTaWosagxJBCJVqK+AtMYyrBEIT8Ax8ghKSKXVKkuPiobAyKlW87jYXGRm00RYSACDfNnDAe' +
    'zkVc3bDXWjN79l5J8j2RgwTt6EAtfmMH+yjFxIoc8TCO8DUy6MA3HGIoJj/J3DqLQYzhR455Lz6h' +
    'B+9Qil8wiRfoLiOGVXThJd5DEv6ggC204tzDaMQBOiuTkQQ+BIOliHSBZuzhJmPwB3V4nrbwGsUM' +
    'qQFvcILP4RyjiIHUoIDjnKdWoRqjwWguqv1EITUoeTySeAq/0JJDusVfzIf/GI9qLThNDVbCAsW4' +
    'xJcgfBvO2YVbScf4FNuPGGNTWOtncQszWETNA+JaLGAKZ/EmTmEDm+grI+4P9TVMZ7NQwkQw+RiC' +
    'to5r1OMV7kIGlv+PokycoS2ksB5X2A1938M/cFlGQcb1Ok0AAAAASUVORK5CYII=',
    // 9 Pause
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABF0lEQVR42pXTvS5EURQF4O9OPICJ' +
    'ksJUUwpDQhAFglLmKUZLRGfqQSUaUVJOiGoaQlT+QuenQUGHF5BczblyTWYyuas6ydlrnb3P2iuK' +
    '17VChCGUkMc3bnCHOF2Ya0Eu4xH7KYESDvCAxXRxV9OrW1hABactxKexgwmsIE53sIZxjLUhwwlG' +
    'MYlViMIfFHCFAXzojF7cYyTpYAm7TeQY1XCuNn3eO/ZQSQTmUJcNdcwnAgU8ZxR4QiGXajcrorQL' +
    'ryhmFCjiJRFohAXKgjIaiY39uM5gY19Y6+H0CJs4QncHch6HqOEtvYk1XOASM23Is+H+DBvNWYix' +
    'HES2Q9DO8YUeTOEnZOD4z4o2cYbBkMIefOI2zP0Pv6y5QAtW5wDrAAAAAElFTkSuQmCC',
    // 10 Stop
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABMElEQVR42qXTMU+UQRAG4OebJTGh' +
    '4S5BaACloYHWjoJgyz8QqKE2lobCHmnhD5DQU2KMWlnTEAs+rEnQxGqbo5kzH5dTEN9kkpndnZmd' +
    'd2aaWsIY9PASC2l/xxl+jD4c9Z7FEVpsYw7zqbc4xEzXYaKjr+AUJ3g+JlsPb/EVGzgHtYRaYqaW' +
    'uKolXqX9N9msJdpa4mktoUkOjvATbzwM+5jETlNL9LK+7rfXUrr4mAJ9XOLZRLL9aaTmNeyNyTwM' +
    'cIMvWA8s4sK/4wKLgQGaRwRoMIisZekRAZbQ/jeJwzYe4hdePzD7AZ5gtztIbQ7JfYO0VUtc1hLT' +
    'tYTuxUoG2a8l+mMc+7XE+3ReHp53d+EcL/Au6/uMbx3CVnGcb65/t+IP6zyF9SRWkvwhx/0ObgHd' +
    'a29f4EsXTAAAAABJRU5ErkJggg==',
    // 11 StopAll
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABYUlEQVR42o3SoWuWURQG8N/OfcMX' +
    'Fg0LhoWZJmyC4AcK2jQsCE7YHzDBYN/CFxSLwa5txnUtYtAiOFB0QRY2WFE0rClsHBUt95WX1++b' +
    'u3Dgcu5znnuf5z5TWcIxa4DruIhpfMQmPrWA46bPYwf38QufcRW7WP+LyhLjai5LfMsSoyzR9M6G' +
    'WeJLlljPEqYmSBjiFJ5NeN0QL3GmTzCD27hQ9W/jCT6MIXmB593pVezjRjXrNebxHo/R9Ai2MN82' +
    'l/EIt+qNfTOf4ifudPrT+C5LDKopq9Wk2V41WeJsljjMEosV02SJ3SyxIkssZYn9jsu/ezVb+xtZ' +
    '4mHdj+rMILCIN/6/trCAJazhJo6aqq05AUGLPcA57LVJfItLJyC5jHf1tXvdJLaGjCakUpa4Uk2c' +
    '6591AT+yxN36K13QcifW/5B3k3gNG1XKKxzVyJ7GPTwYp6sf5QFWelHexNdJxvwBmhOWqTwAy7kA' +
    'AAAASUVORK5CYII=',
    // 12 Help
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAg5JREFUOI1tk81LlFEUxn/Pfd9X' +
    'hQQn6GOVKYWlmRTSrijMTWCk2KiF/SPBFDS6jFq1DvoQZ0olahMUlLUIMQcbE0lQWkUflKtyxnlP' +
    'i5km35m5y/N83HPPea7MjMqjmUyMXHAWaC6VPlOXf2H9x35VcbcbaCK7l0BJTENgr4BVhDAOgE6D' +
    'TeIXEjbQ9bXKQJPLnbjwGVIKPzdeeZtmMjHyQQIYJHR9NtyeLRtoenEPW94c0lW72PEAKNby3qmi' +
    'Wm8t3vEFQKnsKNIY5E5Y/Pg3B0DBG0NKlcWp5V62vFXEHcRtsFU9yvYB2FDnfcQUFiQBnGYyMUxD' +
    '+Lnx//0WbgHLNNY3w8cW4B2mm2U8FyaRG1F6vskVp22vI2/2/TP4hfN27uAmfw41ALuAwj/YLh/9' +
    'CbyB+h4frBW5le0Ds4HDPwB0b3EHDd5zYB+h640u0FbAtfo4Z4ShKvcLQIN3A+gipMeG299HMCFC' +
    'MwfhGlJbTQNoBO7a8JG5KsTUhmxdTC/EyNetE+RaaiWt1tHDDzsJvDX4vd8VRTZZCkmUmF6aVXop' +
    'U+UQeNcRExbv3ijmwC8kgEGlsqMVfT7BeBw1zV4Bu0DeT0B1lJ8ipsiFydKqom377hqiH6c+G+xY' +
    'ihgU3Rd2Y0ESuRGwWcSn8sDgJGKCvJ+wS23fy5qa3zk93wT1PZhaSqx12Hxp8e6NSu5fWuPdR0xI' +
    'M78AAAAASUVORK5CYII=',
    // 13 Website
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABRElEQVR42qXTIUuDcRAG8N9eBhoM' +
    'C4sGm4IGxQUFg0UQzLYZ7BoNfgIRo3aDFt0XECxGQcEyQZtBsAw0GBQWLM/kz5jJgxfeu+e5+x/P' +
    '3dVcdo2wJlYxF7+LG/SGidWIxFO8oYONfJ3ETsP5tXrxP4PrvHKBMWwG6+Ab83jAGp7KDppJvsUy' +
    'pnFYFD9MbDmc60EngwJHeXkLDUzivihwn1gjnF5yVKnUxj6+0Morw3Yb7CvcNppV1P7EVYhTeB1R' +
    '4DWYcD+xWs+o+lFYhFL4ivgKFuP3MVf5p9WzJHVsJ7YTxXeHuMd4xkn8d3SrbNgE1gO8RPFhmwwm' +
    '3AncVBnJOQ4wnpEtjSiwFGw83HP0BhrsZZxn+IjirSK5ldhHOM3kqBXHVK7y4x+rPJvk31Uub+EJ' +
    'C9mwdrC7ooN+2t4rr7L233P+AT4rU6EqtPz7AAAAAElFTkSuQmCC',
    // 14 Reopen
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABUklEQVR42qXTv24TQRAG8N+eLHFI' +
    'FASoqBwJF4R7AESXgiol5Fo/AX2ojCt4C5T2TEmXhodYp3GQ3YMQICOZwgxFzo0dGyGPtBrtp51v' +
    '/nyzKSLsY4U9rQPpw+VAxGvcavHfUnobL4+G/yJIESGNxgvSwzg9+gZpdHmP+Iy7O2K/x+mTAxFB' +
    'kyMi/M9Zxew9g6TJX/Bg56u6ShtYkwNfO/ipKJ7Fi8eTDfaUaHKpyW/QRxcznOO2uloUmFjq3Zi5' +
    'ySUucIJXOGz9CS40uSwkV9Kyd2N2zlDiWF19xBQZxy1+VoiYkB5t6b6Pobqar81kjiH6Ba6wjaCL' +
    'vLbuU01+31bS7fjTmSiWvS0EM1QppVl7P2z9HE8x6/jxa+qgvJ9G49iQ+HraA03+1JY9VVdJk+9g' +
    'gPO06zem0XilQtn2nFG1wQs8302w2oNrNdb34J26WvwFj4Oe4ypWYQ4AAAAASUVORK5CYII=',
    // 15 SaveAll
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAWElEQVR42mNkQAarrvxnoCtYdeU/' +
    'E6VmsJDk7DAdRqzOwBsG+ORJ9kKYDiO6ISx4bSQqDAj6ET+gOBaoEI3E+h+H91iIUojH4AEOgzAd' +
    'RopdwEhWFkYKJwDrxCQTLHvCbwAAAABJRU5ErkJggg==',
    // 16 Close
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAU9JREFUOI2Vks1KAmEUhp9vnNHW' +
    '/Qjt2hmpm6luQKl1EA0h6TV0J96D2A8TScsIzBbtAkEarXYuC72AmnHmtDAnMh31XX2cn4dz3u8o' +
    'RrIdYZoED032Oco+TK2JBNiOYDsf2O3ceEqbThyXOgS5GIfMD7DSj5Mg+twA2xH42VLkFohPKFgE' +
    'NtQCHvxRd/SIXsFuL6OkhGdUKaT6YXxg7HLlnCKqEj2BkhJCGd1tUGslAai1kuhuA6GMklI0QNwz' +
    'EAdUhoFW56a5xUCrg8qAOHhGNRpgmT3wcqCeQWVwE81hM6+g7VFI9WebaJk9NN8C9QmSQHAJOMZK' +
    'v8M8v2A31whiNsgS8IUijsYl15312YDzt1Uw7kGyIA5x1xx6wia+f0ftZSUaYHgnoWF6kOfA7KAH' +
    '+dBY3y+q31H/XWIX1HZ4B7r3BGwAXfTYDr5fRFTlG6BoiOLxoybDAAAAAElFTkSuQmCC',
    // 17 NewClient
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABAElEQVR42tWTPy9DcRSGn1/TmaQf' +
    'oPUBsEvEYhKbpGXnA9iMtVp8kCs2oo1BgliV3DY2jCS19HbA7X0sSmJwq52c5AznJO8573v+BKJY' +
    'JrACE1oRgMDeWGjZgShWZRwnip1Ywj8pEEIAmAbWgMpn/GcGJ42kdfhmeq2WvtO/bOFrW1oYmGUh' +
    'rnnZv1NdHImBOqVeAQM1iGRkABfqozqXJ2GlkbQWCu11ip0NAJbu64R2jd3ngzKwmXdIM6/Z+8tZ' +
    'Etvs3Uhcdb975Glyazftpepq7gzUkrqcZgOJq573O6rbajl3iD8KPdSfomHnyvCUw0jvXJsN6jyw' +
    'BTRDCMdD3AeYgBnV2Xz3PAAAAABJRU5ErkJggg==',
    // 18 SwapClient
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAc0lEQVR42qVTwRHAIAwints4j7N0' +
    'Blex69h56LeXizZR7nwpEFAFfRAHSDhEBgAI2habuIA+SBI7C33QHUHuh0cdsBaxRLLHRZ9hLWIK' +
    'fDc85FAEizwVsKLMpktep/VDUs5/ZS5LjE6QvPcd+kzhDiKOGi9Uk2X3btHtugAAAABJRU5ErkJg' +
    'gg==',
    // 19 Format
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAIJJREFUOI3d0sENglAQhOF/iPbh' +
    'WSgBu4AQa6Ahe3hYgBdDE4+rpYwHThgTeHKQsMdJdvJtsrLNmjl8BgpxUaPrXADamUAhRuTWVdHP' +
    'ab4KFIYSfAddXZ+fiwQK8QWcJqn8AI7pgm64YHdJgmmtb8iNq7wfT0oU/DIb+4O/CLJV28AbiCdR' +
    'eGXjcHAAAAAASUVORK5CYII=');

implementation

end.
