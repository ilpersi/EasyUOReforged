unit mdicons;

{
  Port addition: the MENU Designer's icons, written by make_icons.py (in this folder) from a
  Lazarus install's images: do not edit by hand, run it again. Those icons are by Roland Hahn,
  CC0 1.0 (no restrictions), as Lazarus' images/copyright.txt and
  images/general_purpose/lazarus_general_purpose_images.txt say: the 16x16 outline set
  (general_purpose) for the menu and the toolbar, the component palette icons (components, 24x24)
  for the palette. The sets have none for Select all or for the Arrange commands: make_icons.py
  draws those in the outline set's colour. Base64 in the source, as easyuo\mainicons.pas does,
  so the executable needs no other file.

    NewDesign   general_purpose Add_01_16
    Open        general_purpose Folder_01_16
    Save        general_purpose Save_03_16
    SaveAs      general_purpose SaveAs_02_16
    Paste       general_purpose Paste_02_16
    Exit        general_purpose Exit_02_16
    Undo        general_purpose Undo_02_16
    Redo        general_purpose Undo_02_16, mirrored
    Delete      general_purpose Delete_03_16
    SelectAll   drawn: a dashed frame round two boxes
    NewForm     general_purpose Window_02_16 with ovl_Plus_06_16
    DeleteForm  general_purpose Window_02_16 with ovl_Close_03_16
    MoveLeft    general_purpose Arrow_02_16
    MoveRight   general_purpose Arrow_01_16
    AlignLeft   drawn: left edges
    AlignRight  drawn: right edges
    AlignTop    drawn: top edges
    AlignBottom drawn: bottom edges
    CentreH     drawn: centres across
    CentreV     drawn: centres down
    ParentH     drawn: centre in parent across
    ParentV     drawn: centre in parent down
    SpreadH     drawn: spread across
    SpreadV     drawn: spread down
    SameWidth   drawn: same width
    SameHeight  drawn: same height
    SameSize    drawn: same size
    Front       designer order_move_front
    Back        designer order_move_back
    GridSize    general_purpose Grid_13_16
    Preview     general_purpose Eye_01_16
    Help        general_purpose Help_03_16
    About       general_purpose Info_01_16
}

{$mode delphi}{$H+}

interface

uses
  Graphics, Controls, mdtypes;

type
  TMdIcon = (icNewDesign, icOpen, icSave, icSaveAs, icPaste, icExit, icUndo, icRedo, icDelete,
             icSelectAll, icNewForm, icDeleteForm, icMoveLeft, icMoveRight, icAlignLeft,
             icAlignRight, icAlignTop, icAlignBottom, icCentreH, icCentreV, icParentH, icParentV,
             icSpreadH, icSpreadV, icSameWidth, icSameHeight, icSameSize, icFront, icBack,
             icGridSize, icPreview, icHelp, icAbout);

// The menu and toolbar icons, 16x16, in TMdIcon order, into an empty image list.
procedure LoadMdIcons(AList : TImageList);
// A palette button's glyph, 24x24: the Lazarus component icon of the type's control (nil for
// a form, which is not on the palette). The caller frees it.
function  PaletteGlyph(T : TMdType) : TBitmap;

implementation

uses
  mainicons;

const
  Icons : array[TMdIcon] of String = (
    // icNewDesign
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAJ5JREFUOI29kcEJg0AQRf+K2ExM' +
    'B+biIQ2EbIuBqSBHwS1hUoQ1eJgcNoIZZsKqkH+c/3n8/RuwiFjgSTCjkivu58HN/AQQC4gn0KvX' +
    'VuUTtcINkIeGlAPiKVmQuhhALMDnlSJPAI0R2ALL2rCBrT8CiEcQj/pcPiLQHWuwVmxDWYNcuVO3' +
    '5QcSYns5PKJF9n0js6/BClR7xpfyaMmy3gqnPad0fErOAAAAAElFTkSuQmCC',
    // icOpen
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAANVJREFUOI3FkzFqAmEQhb8ZV2Kp' +
    'QVKk3hXUG3gN42FSSaqcIUeIpvYUlirCv15AxUgqA67PxnTB8LtFHkwz8L0HjxmTRBl5KRpIAOxj' +
    'MUR6Bu4u+2/MXvXUefnLwCRh4/kB7FGDzg7Axot70AqoX2H3GnQbSILRTJKImR+mdAfGaLYBmjfy' +
    '2wT4wr2nfjtEJb8vW3gxcSBQkEVn+zEDQoKRQxFvACmQO1IAS6NxswyUO5Bf3OIkUlQJzikJcEMH' +
    'kFEhGG/TKo3amutX95v2fB4e7N+/8QwA2G2c/wql3wAAAABJRU5ErkJggg==',
    // icSave
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAALVJREFUOI3tkzEKwkAQRd8kC7bx' +
    'BqmT2ygR7LxJ8CZ2SgKexoCduYGpw8axiEoCK6vB0t/NLLz5w98RitMViPhOR5C1ZklrgEizVJ4v' +
    'UlY6qg/nmMBuuJkdYXcBmYEWoHtgGXhnGRsjkmNsDKBZ0oKsgAWAH+BQD+nlB1hTo7rFmtpp0NFr' +
    'pKz0VYUAAmGXA40XoFk697pyAaSsPo2zGQ4ZOhjF+U6j9ZiYwh/wY4BMPGd4/Ic7ySw5+eif6mkA' +
    'AAAASUVORK5CYII=',
    // icSaveAs
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAXxJREFUOI2Vk78uBGEUxX93ZhKF' +
    'ZEOytiLZkC3MxjvwABQ2IyQKwiOIUIiotuIFKBSEmIRGRST7DgwKfzaodgpLNGTMVYxZViYzcap7' +
    'vy/3nJNzv084uHgGuvgfDkGm1LE/LKBLnbLEN+J62tbvXxcxghlCaxvz8x6kA/QAdA+oGJlaVlBE' +
    'ZBUrKAKoY3+ATADjANkECYhIImQTBFYd1TUCq55oMOGsKa6nrc4EEDA/V4FmJoE65e5MVxEO2wjE' +
    '9ZLWWafHL9HILyIyB/QBjwi78Dr910HbOgGkVrPw82eIvICMAjcYlAhZgdyJ1Goj6SE28osgL+qU' +
    'x9SxL0GvtGJ76tiTQBO/sJAU4i8LMvetHKO/VYXGMkZ4lE4AvcCNuN5tPPy9oTtyHTZv731ZBE8Y' +
    'lLRSHoiH45zEPR8C4zE9A2E3CqyFu5/SrCJspjvQ1yrkTsW9PCaUJQwZjJTNKmgneX9D0r+zzNLT' +
    '2MEvLIDOE72DB5QtCv66Dg8HXyJhhFjIaBVqAAAAAElFTkSuQmCC',
    // icPaste
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAMFJREFUOI3Nkz0OAiEQhd8Yj2Jh' +
    'ZOMJPIHbSoxXXLTE2isY2S1MvIalz2p/YIFVK19FmOHNxwwISbQSU18BrNGLgNypV0skJKhuFpBt' +
    'd0Ir8RJM3VcAz9RF6VtUjiRB0lvH9mLxeUD0EFO/AAwo6FL4AHwDarXIJcc0+yY57M+IIJTfQE9P' +
    'CEvuikvWIFVVTLMBcRLTHCYNYiTUSuTo9iBsdDS5sYXxnwiGV/vIINaHVn9BIDZXYZJu+J1HwfRD' +
    '6vQG+LiiH/bEUjQAAAAASUVORK5CYII=',
    // icExit
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAbBJREFUOI2Fk0FrU0EUhb87ja2C' +
    'Lgz2F7QLfYmCIOKu3bpTySuFVvQ3iJGiSOlGsOoPqAurbdH0TfwN7VZFhL7nKFLEvejKjVBzXLw0' +
    'IX15ZGBg5nDPuefeuWOSKFvWDssAakQrZTGuQPLpjPlQBUCaRZrN8VA1n86UCpgP49YOm+B2Mc0X' +
    '7Wge3K75sGHPPx4b4kDrSAtID1BYKwgorGE8BC1SPfGij0vg0xskmUg+L0nicJNkOyTZzgC2nd4n' +
    'ycR2uCap60B2DwiEaLWsWf1SvjwGvmKdJoCzN9/OAJfBNrVMZxRfcfwPtAVcsdfp6QrjB1N0MGR7' +
    'xWwUe5E73sNwTNhUpQe64kCoUWsNFXASsvyIc/uA6OjCKPt9ZVfPOe670/Wzv4D3mBZtpThYR5d5' +
    'Pwa6CXqnOPrdJdhTsDrnsjuj09eaQITxBMAkYWC0sxayBmiJUH929EXM+zEU3cV4BLQU1xZ6AgD2' +
    '8sdxTv55hWwOlAEbmMu6RZ9H3AIiRItTE7d1dfrvgEAvUzvESE3gEmCHbQM+IFY1V3s7EF/2nc1/' +
    'moTKdH472Fd88eewuP/S28YluV1MxQAAAABJRU5ErkJggg==',
    // icUndo
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAUtJREFUOI2dkUErRFEUx3/nvZeU' +
    'nZKFD0C9mSlFSVlIWSPPhIV8BB+AYsGCfAHZKTHDTko2NiwmGzw7ylhJlIUVc/8WU8NMM+Pxq7O5' +
    '95zfuedcJPEz2I/ba8+ahccPLBcvg54td9VNQioCy8crwBJwRMfrXVJB8N2ZReCY97YpReFnUoGR' +
    'i2eRdhKklkCPwCGBv6rxnpeyIH+dwdkFmI/TGR5vDQweEAI9QBHfDWsifW+SsIPbXpxOy11KI4rS' +
    '1w3fsR/PYbYNuiQKB0xS+WIv7sfjBOyDT5fWdOqpoSQfbyIWwIYqv6BsWMAxCjqHllLTdcgOyyb1' +
    'BVXn2bAAjDUtrsH7PaUukwA4CpUdJMXyt/OILXAFotRg1Qi2e9NJ4K2DWuvU+mAhqBt4ADcjUJUA' +
    'z+8CFwF1BFYCiphtINYUZV4B/jxCLf9dYoUvb5qhbSZBFD0AAAAASUVORK5CYII=',
    // icRedo
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABR0lEQVR42qWSPy9DYRTGf+ctFoOk' +
    'IgZBGAhlQyIddBAxijZtmhgsPoKBhISP4AuISeIKk5jE1kVC0vY2NfgAQmxNOvTex3DTxJ+ieJJ3' +
    'efKeX855zkES7T5O/PhHz9GmzCuOg57M8/fe+m0D6Ht5AC6AXTv1938NUCrVoNadBS4RO81OTFLU' +
    '4nm1l0awDayCDYJiP89layYJOyuNErhrYAioAj4QtiwK6cHZAijAab7DwAjcMdgA0rqyiaOvgyxN' +
    '42JXoBrOFpVOFB1eJQnMYTr4tvi43A+xK1AnIctKT95FIZpmopTs7PuBuwJQgZAl5RI3Tbej7S3k' +
    'x56BlY++I6RJy/AHGZLhlQvgZjE2lJk8/BVAEuYVRyB2DQyD3YN8IGjxvU4j3FR+6vEdIFpRJY6x' +
    'hUhH99DykOqELqncxO0nwF/l+KdeAfDTpIQRfuVLAAAAAElFTkSuQmCC',
    // icDelete
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAaNJREFUOI2FkcFqE1EUhr9zJ2WG' +
    'Kkg7rYKLqiCEtlBx5ca+grgpLYgv4t4n8BEEIZm15gHUhStpyexKDSpBtJNAm1qJnflddDLJTEdy' +
    '4MI9h3v+83/nmiTqwl4fXCNoPMJ0E9lP/lx80vOts+q7Rm03QOB9h+yAzPpYdpvA2wKWrgyqc3A5' +
    '3RuRaQOnRfDOQTFj/4ae3T+5ImCt+AGevUC6B6wB14Ex8APsNygAbgE+MMbUA3dEqpdTBMkHOyL1' +
    'nmqv2f8fmUWfV0kXXuEUADgA7W7ug73DdKK9Zt+iuGOt7vplQ/wFwFrddYvijnYe/sLsFPFWu5v7' +
    'bkZ8gFjO53iYreX1uwA4d2cyEGMZGED5FwaQC0gJZmHZOyGQ5NkcAeM4b5hGloXAcSGgeQ6kigML' +
    'MZs6kAYUTAC+NywEnKtH0AyC54YlAT1pngIL1jn0EQlipSQgW0FKrHPoAw3tbIyqCABDRuOl2iWS' +
    'hTgSzv8WCywjzO5B+gpK81ovZ7gg5RtSSQBJxaHd/Ug7fjxbqx6ieJt298MkryL0QO8tipkTbyaX' +
    'f8HRzi3eUjZUAAAAAElFTkSuQmCC',
    // icSelectAll
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAV0lEQVR42r2TwQ0AIAgDi/M4D0My' +
    'D/vgHxNFG+XD72iOFDAPALje1JgHTZKZmEa71BNkQCFdW14oOGiUA+1COxCYx17UAXQLSNJpB/QX' +
    'Pjh43QVQVTaPAVLvY7nzc4/9AAAAAElFTkSuQmCC',
    // icNewForm
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABAElEQVR42tWTPy9DcRSGn1/TmaQf' +
    'oPUBsEvEYhKbpGXnA9iMtVp8kCs2oo1BgliV3DY2jCS19HbA7X0sSmJwq52c5AznJO8573v+BKJY' +
    'JrACE1oRgMDeWGjZgShWZRwnip1Ywj8pEEIAmAbWgMpn/GcGJ42kdfhmeq2WvtO/bOFrW1oYmGUh' +
    'rnnZv1NdHImBOqVeAQM1iGRkABfqozqXJ2GlkbQWCu11ip0NAJbu64R2jd3ngzKwmXdIM6/Z+8tZ' +
    'Etvs3Uhcdb975Glyazftpepq7gzUkrqcZgOJq573O6rbajl3iD8KPdSfomHnyvCUw0jvXJsN6jyw' +
    'BTRDCMdD3AeYgBnV2Xz3PAAAAABJRU5ErkJggg==',
    // icDeleteForm
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA2UlEQVR42sWTO07DUBBFz4sspaBh' +
    'AUmFO+jZRqpsIa0lP8EaQCmyDi+EsAArULwmdVw4C4gOBZiCwrbigpGmme+duTOBqpYJMmOiZAAE' +
    'Xq7KlmeoalWuUaraySP8f4FsKCCE0OueDSWrG/Ws7tWlulDffmybXhYA1PaY5zZlqZrU1JSlxzxX' +
    'bbMRY37erFaP7XaLl8sdwHm34zZGgI8xCJZqOhWFCUzgqSg6NIvRLIT5/M8Vdi80jOC9ifG3c4ek' +
    'iVF1P3mJofed1w/hmypegQOwBgQq4B54+gJyNhlb1e5vogAAAABJRU5ErkJggg==',
    // icMoveLeft
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAMxJREFUOI2l009KAnEYxvHvM0Pt' +
    'XQlti4K0S0hHKBjEDtHKY3iJsBmaCwjiGQT/kdAyt+3T6XEh4sZgZn7v/vnw/uGVbUIqCkr/Byhb' +
    'tTWcNWoByhcJkadcRv3KgPJFgvUGXrP1oAyg4xKVL5+xh6Avirjj5G5TuoO6YQCRLR+RR+BfYA3a' +
    'lov6D9MPPqNsB40QAfjp/gOpC74mLiZKP68qASeEF+CGeDfW+7xZCTggrRS5B7rlQq9lAJ17JmWr' +
    'NsXu292Hn1pAlQo+4x46SVwk/We7OAAAAABJRU5ErkJggg==',
    // icMoveRight
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAANFJREFUOI3Fkz1OAmEURc8dBnoa' +
    'LewJhIlrQCpbE8NPQsEWqFgDlVuwmIAYEnegWzAyBOIOZAv8XCoapfhgCl97c09O8t6TbfJMlKsd' +
    'CtB4XtZ0mVxuUIqGRP7UbNG5DLDxE/gbK/0NCQK4m/wQ7xrgFVaq16x3ngHgh9s18a4JXqHo+QgR' +
    '0+wOMQIFwlwEKqAS7O9zr1HnHJLevq7YFt5BVbzvu5WkwQanysEGmmTXxPoAVZB7fqy/HLMwg6IG' +
    'p8rhBuN5mUJ843Yt+5P9+zceALEtUjQpMelXAAAAAElFTkSuQmCC',
    // icAlignLeft
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAPUlEQVR42mNgoApYdeU/uVpZyDYo' +
    'TIcR0wAkCWJdzESp7yk2gIU6AUpBLFDZC/hcgiN2iItGPAaPRiMVAABcchiUdKa9ywAAAABJRU5E' +
    'rkJggg==',
    // icAlignRight
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAARUlEQVR42mNgGDCw6sp/BgYGBhZ0' +
    'AaJAmA4jjMmCS4KQzTDARKlPKDaABZ/z6BILVPYCsd7BGY14FA6VaCQlHKgVjRQDAJRAGJRH2Hcz' +
    'AAAAAElFTkSuQmCC',
    // icAlignTop
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAARElEQVR42mNgoBAwMjAwMDCsuvKf' +
    'LN1hOowM1HEBLlfAbMAnh9MAZD4eOSZKvTAMDGAhWiWOtMJCaYIZbGFAbp4YUAAAFAgYjMTAmkcA' +
    'AAAASUVORK5CYII=',
    // icAlignBottom
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAASklEQVR42mNgGGjACGetuvIfQzZM' +
    'h5F4o9ANwGYgFsBEqRcoNoCFLO8hhQ8L0VYhByiSgQMfBoMtFvAlHiITFpl5gVzTScorOAAA8+sW' +
    'D82WL4MAAAAASUVORK5CYII=',
    // icCentreH
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAQ0lEQVR42mNgwAdWXfnPQGvASJZt' +
    'YTqM5DsXTR0TpWHARLpTUQEL3UOdNECEixhJ0kREmKAagItNzVhgGoRhQO90AQAajyV1iFYlNgAA' +
    'AABJRU5ErkJggg==',
    // icCentreV
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAT0lEQVR42mNgGGjACGetuvIfQzZM' +
    'h5F4o9ANwGYgFsBCluFIrmMh2oXI3kEykInSQGQi6HcYHxdNVCDikaPYCyxkRzNJBuBJUCzkJJ5h' +
    'BgCHLyx1JF2XcgAAAABJRU5ErkJggg==',
    // icParentH
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAASElEQVR42mNkWHXlPwO5IEyHkYFs' +
    'A6D6mBgoBCy4TMbtZEIG4FCIy2CKvUCDMCAUDgQNwOZ/sr1AhEuYCKe0Ye8CRspzI4UAAJhYHJrq' +
    'PiDIAAAAAElFTkSuQmCC',
    // icParentV
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAATklEQVR42mNkWHXlPwO5IEyHkYFs' +
    'A6D6mBgoBBQbwILNWZj+JNYAdA1EhA+dwgDmEnSaaANg3kKnqR8LRAYcbgMIRNkAxgJBL1CSIykF' +
    'AJ2FHJ3sNtDoAAAAAElFTkSuQmCC',
    // icSpreadH
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAATUlEQVR42mNgGPKAEafMqiv/4eww' +
    'HZzqmPAaj0cjDLCQYht+FxCjcdWV/3BMlBeI8BYTpbFAugHI4QUPRCwSxMYKCzkhT7wXiHHV0AcA' +
    'hsQXlwsvnA4AAAAASUVORK5CYII=',
    // icSpreadV
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAARklEQVR42mNgoBAwYhVddeU/VvEw' +
    'HUbijMVmAA5DWUgyZFACRrKcjTMwiTEATQ3L0A08/CkRm1eIToXYDMATLiwkJ+lBBwCubB91zUOG' +
    'jAAAAABJRU5ErkJggg==',
    // icSameWidth
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAPUlEQVR42mNgoBAwwlmrrvwnSWeY' +
    'DiOqACkGIKllotQLFBvAQrY3iPEfMXKMZLkAIwao4oLRdEDFdEBvAAAV6CH2O5ZfDwAAAABJRU5E' +
    'rkJggg==',
    // icSameHeight
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAR0lEQVR42mNgGGjAyMDAwMCw6sp/' +
    'DJkwHUY4m5A8hgIYH53Gop4Jp9twaUYDuA2AORHFqaQYQCQYNWAwRCML0cmVgEsGDgAA/BskBhXo' +
    '2CAAAAAASUVORK5CYII=',
    // icSameSize
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAX0lEQVR42mNgoBAwMjAwMDCsuvKf' +
    'LN1hOhD9ZBkA1cNEqRdYSLEN1dkQwESaXzEBE9EuwGMI/kDEJUdUIBK0GZsBMBuJ0IzbBURqxu8F' +
    'IhMXCylRRn40EuUCcjMUpQAAjfYnDJ1yXw8AAAAASUVORK5CYII=',
    // icFront
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz' +
    'AAAOxAAADsQBlSsOGwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAFZSURB' +
    'VDiNpVMxTgNBDByyobyCOhcCDVRUNGnJU5B4Bg+g4w9IPAUpBQRBg5QIKgoqipOI1h7bFJdALhcB' +
    'EpYs7xYez3h2gX/GFgA8v7y8U7XIqtAsUBWoKkS0Go1Odn4C6AKAmRWDwSCJCHLOyDlDRDCdzorf' +
    'GHQAgCRIQlUbSdW/SXh4fORuv59yzri++cBcArQA3UGDmQXMAwxUl2eHDUndJYPl1LkEjo/2YeYQ' +
    'NYgwiRhEiPvZW0tSZx3AIxARIB1UA/md7rF5iW5WTaezQlVgvpdI/27U5dlh7f4aYDgcfuk6v5pR' +
    '1ZLSoHQoDap1Dfc0Ho+5anFnHdEdrcn13WARKMsy9Xq9RLL42kEDIGJlstV1wcYdLYu7bQZR3T69' +
    'FrV1gLmnRcV2WgEgNwNcnB40fL6bTNgvy7R8oTnnBkBLwnpseqE/MmhJWrFY8uKTqYBk9Vvvn+IT' +
    '9YJyA03rjTkAAAAASUVORK5CYII=',
    // icBack
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz' +
    'AAAOxAAADsQBlSsOGwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAEwSURB' +
    'VDiNpZMxTsNAEEV/4rQuqANKKiI6RAMtuQlIXAKJA9BxBcR5UCiRbJGKgiqFq53/Z5ciIXKyJkZi' +
    'pCnnzfx9WuCfNQCAj+VyJbIMJBgMpIEkzNjM59dHhwAjAHD3cjKZFGaGEAJCCDAzVFVd9l0wBABJ' +
    'kASSOy2yN8IIQDa4BciL++dK7gkeE5TQPN3NjjJA13aSkAvns3Fh5jAT3uqvLNLwIECC5NuOMXVH' +
    'iO5NVdUlabDAQiICDR4HEOMGEOH5/Fpjux5eal2cnRRGwcxxdbxCVICRMDOI5m3Fo31AjFhv3GxO' +
    'kZhOJ2gpLtqKhxkgJVARlIP0XsUdF6Tm9f2zXKsDLscsfnvgTsDj7emO55vFQmQO+QFkEfbrkOLO' +
    'C7JIO4o3n4wGSU3f7J/qG0iMd14pJP1BAAAAAElFTkSuQmCC',
    // icGridSize
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAALBJREFUOI3tk8EJwkAQRf+3Aq0j' +
    'lqASrMEcFKzAa1KKTeyuJQj2kJ0UIHjWDr4HNYKHJAt688PADMyw/zE7lISX6O0KYIxu3VRkk7aS' +
    '1AZcVEouCaOe13rFDwR19L5dFxm/h0BvxhDzZOsh5vRmhLMZoAPANaDjsGkuIAWA66etuoKLl6EI' +
    'cPEMV1cPhNDMAZYAtwkAG4AlfbMkXDRQO62mp5QtMMQc4v7/kX6AkHzOdykJI0CvefpjAAAAAElF' +
    'TkSuQmCC',
    // icPreview
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAgxJREFUOI2lk09IVFEYxX/fe9Y4' +
    'YoP2h6BcKC4qn7VooFoUuLCFEeGih61aDrYqCPwDUS2NCDcRLiSIlNCRUAgiCookBEGCbBwISxIT' +
    'aWNT2Iw9550WL6UJV3lW9x6+e+79zneuSWIrcLZ0Gij7l7DB2QSx1VbgJKImIllAGie2bVTnDvwo' +
    'qV9vwdJpF/M6kK6Cvcb0AmwuKlMdsmbQKbA7kLkt3y9uCNiTqQrysTGwEIrt8o/MbYjiufIbfkX7' +
    'd3Xg9oEZ8XyrziZ/Rh7kY4NgC8x4LbCy5I5kr+0YzX53HC/AVLB0JmfD071QlmPGa8G0SD4+EHWX' +
    'fn8B0cFy4TiJyj24wbO98djOK4dr9tVWlnNv5gvjSznApkC7CNVMbnWe6vJJUI+D6AR1KpUMcIMH' +
    'yIYbqisq6hNxXMf+skv7kXpxrF+pZICpE6y7dAqyAbLew1eWaV8LVSXgzVJu3e8iWe8uhzJ/CMcF' +
    'hcbwdBtYF8uFY0olAwAbyfRELytBj3yvOzJzIg6JKcy6HfmNQ8Anqsr7I9cB2XWMW8AisBit7QaA' +
    'PZ2NQeIRxqTON4xFY4wUHwPbCd1Lajv4YbPU2VD2KE7Yh/jIt8JFpZJBaZDwLgNdoLdgL5E+45iD' +
    'qAedBmpBN/Eb7wtUksSNW9ITcZQ4g2MnCFUDKgLzOM44u78+V1PT2qZR/l9s+Tf+Bvxf4BqAQjU6' +
    'AAAAAElFTkSuQmCC',
    // icHelp
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
    // icAbout
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAcRJREFUOI2Nk09rE1EUxX/nZabF' +
    'lXFR3YUWIWCJIhR31ULdFqzUxj/Vz+Equhj9IIXWkAmELHQjNFB1JdRGOkGKQqNLEbQradLMdZFY' +
    'k8wUvHA35917zn3n3SczYzxUb2bp+DeB3AD6xkR3y5av/krUDhOoHF3AV4CpCLYNfEEI4yJoAayC' +
    '1yvZ7SvfEwSqfCrg4ldIIV7n+bia6s0sXb8ErBC7Jbt7KQLAzKD28Txh9JVqa83M+JuErRxhKzeC' +
    'VfYeEkZtwg9TZoYDoJd5hhTandnN0RvaZj+HkGJhA1HD/ADAU72ZxSaK+J3phJvG6wQG0IkD/MyB' +
    'qjuPXd9te5PmMNI60nqC98Hln8A7mFz0wGaQ209V+jf+9ZSzfXAzHs4Zcax0Ap1JxwEhYjMH8QFS' +
    '/tTC08KUR9Z2eMcN0A3Vm9n/7dWLvXPAPBw1XN88qwyWZFzmdz/Hws88RZRtde7QA8DrlTjOvFcY' +
    '7VqxsDGktZZQr0aPQLfo+tcgucovETU6cTB4qtGxPfcEsYzTkq3MtkYI+uy7U5gfIHcP7C3i84lh' +
    'MI8o0/VKdj//46Qn9TtXd87C5CKm6UFVG44atjp3OF77B1240Z47w/tDAAAAAElFTkSuQmCC');

  Glyphs : array[TMdType] of String = (
    // form: not on the palette
    '',
    // panel (tpanel)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAGVJREFUSIlj/P//PwMtARNNTR8W' +
    'FrAgc3wm/Xtirvj3DyUGnrzPzLIlj0kGqwXmin//lLv/l6fEgs6dfx8iB8zQj4NRC0YtGLVg1IIR' +
    'YQFKfXDyPjMLpDwnH5y8z4xiJuOQb1UAAKGUG/xZ88jXAAAAAElFTkSuQmCC',
    // text (tlabel)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAXtJREFUSIntlT1LXEEYhZ93/CpF' +
    'ESLGIihq9t61iE0gxELyA2ITYyFRbFJrEwv1OhcMgiaBFCGIWqVJm79gZWFs4hcSxB+gpeDHzkmh' +
    'C7uSFQy5jexbnvPOPJxTzJgkshyX6e1VQBWQHSDvaY4T/e6corFUjxMd/hdAKDAMdDTU8+qG9eiu' +
    'gNq/iWYaNdMX4A3YSqkXJ9oFWoUt7XjmAXo9zxS0BjQj+/grZaFigpynG2g/O3GTQFfvDJ038FO6' +
    'tMjQeOTpA1DQmrB3FwV7ggsPbk3gQhgz49vBZzvLJ/oenEbA+aK/k/JDQlGiDResB/gp6C7q4CYq' +
    'AszjImxE4jyf6IWwpqvKSK8O333KKooCA8BxkL0uyN4G2RBwGs3wvLiTm+PlY0+bYU8l9q7l/dws' +
    'gz3TPMzPhU+3VBT6wX3dTdksKnFiy0A/sA4cWdD7GmgFW9xO2QIIsnFnWq2roQW5D2WtZP0flCWI' +
    'k8q0bW/2L4DME9zTx64KKJ0/2+6GC37KjzcAAAAASUVORK5CYII=',
    // button (tbutton)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAYFJREFUSIntlTFrwlAUhc97iYlu' +
    'HdzU4lDIKNjBybXZHNpBCPgP0v4BR8G1Q/0FwWQQ7CJiszo51MEugiDYQnBpoVPytImvk2KHpmIj' +
    'lOJZ77nn493hPMI5xyFFD5p+BPwJADm75nIq/dGQRaiySCIBLny+Wvh4ePViupjOBA3tfFm5zDE5' +
    'ivC12qNExXoEqBzDRdThAHCV8+JyjKpUpFz6zuS6LgzDQK1Wg2maYIwBAJrN5k6QmMCl0JtblgVF' +
    'UVCtVpHJZNBqtQAA0+l04/E8LxQSCnAcB4VCAZRSFItFzGazL/NutwvbtvcHbIsQgu3eGg6HGI/H' +
    'KJVKoXvirgDOOQghAADf99HpdCAIAn4qy9AXpFIpDAYDBEGAfr+PbDa7mem6jnw+/7sTaZqGyWSC' +
    'er0Ox3FQLpcBAIqiIJlMQlVVzOfzUABRb/1ns/J+GuraU5px8kLZcmXfPyVY1OHtUYIxH711F93F' +
    'JapKlAtRhC8CHjCf9t5c4YYcv8z/D/gEwu+R3EWyEdcAAAAASUVORK5CYII=',
    // edit (tedit)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAZdJREFUSIntlT2LGlEUhp/5QGEU' +
    'C21ECGEr2xQD24iVVZo0VjKFncUUimVgpjIpFCzE2PgD/AWmSW07pLIRYtyg3TTiXBjBmS0WBpeJ' +
    'y8CusIVv+XLufTj3PYcrhWHINSVf9fYb4F0A1C8/wodPH65z+e9/oN7fEXz9LH28BuD7z3CjJimc' +
    'z+fUajXS6fTFmuFwyPF4JJVK0e12Iz9RBo7jIIR4scY0TdbrNaZpPvNjHQghsCyL0+lEpVKhXq8D' +
    'YNs2iqJgGAa6rrNcLplOp0iSRKvVolwuk8lkYl3GAJqm0e/3URSFTqcTAdrtNqVSCdu20XWd2WyG' +
    'ZVmoqsrhcLjYWQywWq0Yj8coisJ2u438QqGApmkEQQCA53nk83kAcrncRUAsg8ViQbPZZDAYUCwW' +
    'I991XYQQyPLTkWw2i+u67Pd7drtd8g6q1Sqj0QhZlvF9H3h6tslkQhAEGIYBQKPRoNfrRRn4vo/n' +
    'efi+/ywH6ds8+PsWe/C/MU28B0l0PvvnUp0NwfAXf94KdC5ngyTdfrQb4NV6BFJbkiuq23MAAAAA' +
    'AElFTkSuQmCC',
    // memo (tmemo)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAfFJREFUSInVlr1vUlEYh59DNFVD' +
    'sAmhw7VRBguiNjVNatWpoNygMpiSGP0Piot/RRcHBxvTzdHYpJIOaGKsg40LkeLHUGxCr1doo5Zc' +
    'Wyt+NFJfF0ygFApYhv6Ss5xz3uc9v/OtRIR2ytZW+k4nmFCq/5lSZ8vr9mzudPGOLJ12s9EMWD/O' +
    'wROFN45DTifdlvUdpS4hMgOAiFSU0Ud/TGlS+XxeEmNjYnZ0iIAswNcnMCgi/z9F1vJHkskknbrO' +
    '4akpDPhlwGoB8ltOUbni8XjNNq/Xi3NvkcVXVznjH8Hh0EkXi2Si0ec/xsdHromY2yYIh8M1276Y' +
    'aXKpCH3DaeAmKytCNnuUpd7eG9ESvCUHPp+PTts6udQwpyLzpdoNzOn7nNMfEwqFjIqAZhfZej8n' +
    'rx/6KsJmHwzI2uecTKfF2sxr2IHb7Uaz28jOlo8cUhODeAIx7C6NRFK+nT+mKhhNrYEZu4VvyF4G' +
    'H6DHP4ndpdVkNORA0zS8rgMUzDnmF/s5Elln4cV+evwxPiyvcrKru7UE5Q4m793FA9iKv1l7G8UT' +
    'uILdpdWFN+wgGAwSn3nJ9csBhi7o/FT7eJfJ8CmRqhpIlXbiqvinUmxru6ie6jlo+SQ3qt3voO1P' +
    'ZpWDhIG6/RRjq87bKWFU85Ts9l/FXxGfjD4NAvNxAAAAAElFTkSuQmCC',
    // check (tcheckbox)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAXRJREFUSIntlTtIA0EQhr/dvI74' +
    'ihYKYghoYyV2gmAhWgg2ItibysZerGwEbSwEwcrYB7GytDJYS0CsYuHhEwuNHnp6j7VQEc1tcigB' +
    'Eadb/n/mm9lZWKGUop4h61r9H/ArAFGdMLJCJtPm5Nob3IxCRHQ+gfKuLHlSuk5kC3OYoQHp1NPm' +
    '0rg1HNWW/gjHo2d+R+YgNvpV015RV8pPhykOEItAZ7ObCdK0ACn00wG4HmwXDawnAUBEBvu/veT1' +
    '/SSre0lOb6uPGQpwZ4tP573jOFtFg6l+m94O92eAe1swsdHKWiEJwHlZsrzbQG+7y8zgQ83mqt4z' +
    'QJOhmOyzyR8Y+AoOL15TFsYsYiEeQU0AwOzQa6f5AwMhYHHcorPFD5MaDvAOaYwr4lEY6n4Om6YH' +
    '+IqK7U0PPGoLeX6lH6os+awsTcer0d5bOJ7grCxPgjTtBKXrRHZ+h810SqVjESV0PscTyrwR5tFl' +
    'Ihuki/8v8+8DXgDMXW2opZuxhwAAAABJRU5ErkJggg==',
    // radio (tradiobutton)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAhZJREFUSIntlc1rE0EYxp/ZmS3N' +
    'RxuSbTHtsXqSVZtTLgoV3R5FvehBxUP7V5gPY+M/0d5KoXjpWY0gClJ6qWKogl/Hrtps89FmUrs7' +
    'Ox5CVgO7IUEKFvreZuad3/M+8w4zREqJowzlSOknAv+FAOsnKVXETHzYyatUTlFCVCGlbQvyrfaL' +
    '5Tcf4HWvvaTXNb1cABMhe0VP2sZcej8xMSq8NbNBsbQxYm19Z89pS733Mg/Hj9HziETIXrmd4tey' +
    'Rr0LDgATowI5o6bdmubXRcheDmIECqSKmNGTtnFD56HOnCsBq6ngb9M3z/HQ2VPO7IUFXPLjBPYg' +
    'Puzk59L7ic64bA6hWIrB4hRjEYGMUYeePAQAzKf3tE876kOAXenbAVPkVOdYXAk8ftGGA0ClSVEs' +
    'xTwnkzEBpsgzfpxgAUo8d1WuoNKkXeuVJsUuV3zz+xJwhPRuRTzsYizS3eTxqEAi7Prm9yUgJPlq' +
    'NtpVKwTIGHVPZDwqkLlaByHt3O0GgyPJZz9OYJOrnBWWNkbO54yaBgB68hCrd3awyxUkwq4HB4DF' +
    '9YhV5Sw/kIPNLF5tmay0Vg63OnOEAFqkG772PsI//lSfvs3izUAOAIAeqHefvAsvl82h2fn0njYZ' +
    '+9OH7QbD4nrU+vCDPWMH6v0gRs+nohPTBVzUos4jSuRpphDVcaXtuORLtcVyQZUPJPAvcfz/g+Mv' +
    '8Bscqstuuv4eAQAAAABJRU5ErkJggg==',
    // combo (tcombobox)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAARNJREFUSIlj/P//PwMtARNNTaeH' +
    'BSwwhuekf39M5P6RHF4XnzIxWygy/oXxj99jYNycwwg3F86wUvr3v9ztHwu6AYRA314mhhTTtyzC' +
    'wsIMb9++ZWBgEP6D1QfIYNeuXQQNdnNzg7MfPXrEsGbNGgYzMzMGBgZhFHVYLUDWTAwwMjJikJOT' +
    'YxAREWHYsQ01lOEWXHzMyLjgODNJBjMwMDCcecjIMGXfPwYGBiEGBoZ/DGceMDAyMDBiWqAv8+9J' +
    'guV/eVItSLD8i8J//5XxCXLipF8yRQbERDIywBdnVIlkfIAiHxDjkMHtA2IcMzh9QIoDBqcPSHEI' +
    'zX1Av6Li5H1mls6dfx9SauDJ+8woocI45FsVACksVMxKoUekAAAAAElFTkSuQmCC',
    // list (tlistbox)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAANNJREFUSIlj/P//PwMtARNNTaeH' +
    'BSwwhs+kf0/MFf/+IceQ0w8YZPSkfv1nYGBgOPuYjXF7ASvcXDjDXPHvn3L3//LkWDBx92+GGKNP' +
    'DAwMDAxTj/H9YWBghcvRL4iQwa5du/BqcnNzwxBbe4mbeAuwGUAIfP3FSLwF+HxAquVU8wFJFpAT' +
    'ByRZMGA+wGcxNxukTPv8iwgLyPFBsN5XBgYGBoapx/gIWzCaighaMKA+GHRxQL/i+uR9ZpbOnX8f' +
    'kmPI6QdsMh9/8MFrNGQ5xiHfqgAAhKBMBgIFcb4AAAAASUVORK5CYII=',
    // image (timage)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAfNJREFUSIntlc9rE0EYhp+N627i' +
    'pq6IRw+iLagIngxIL6UIeqjY+gN7koJJTx6kguipJ+1VqMf0H2i8SKsYitBapFRtFKMGpK0RPRla' +
    'k8a6dbPJ9LBmcdkkLGWLIL4wMCzfPO+83w4zkhCC7VRoW+n/hIEMcPa++HryIFaQ4Lll5Ilr0n6E' +
    'ENx5VMuLgPWbaSeoayQdzIm6fVpy5i4DTfUPUaUiHTsfAPCxcglT6A3rXAZRnwaKVOTc7jhtegcA' +
    'J4pxHq4lMfGauBOE/RkcYtyG6z0AtDHJYTPFEvFgEqhV7+lWdoSIyt7aLf2DkriIUU4QYRIAo7zI' +
    '2q5baJK31rUVLewebzeekMgd58xrjaHFLr5YGbQwqJE95KJJ8kY7eaOdXDSJGtGddU0T/NmiTOk5' +
    'Nz+cxxS/AHhTmiWe7eTesRRd+3oAHSN8FYBIi7TuBKo9VmufuJ694MDrqtRMbrzvJ/NjyqnVVKiE' +
    'Vsmuz6AqlqfNLgNFBpMygwt9rJiFhjvaqBokFvqY//4URYb0txTdz47QP9/NqdmjTK9MNG+RJSwG' +
    'X10mV862CG2bDLzsJba3k5nClPM9v77EwIterhyoNU4w/G6I6UK6Jbwuo/rTBW8mV4Kx2ChjsVFf' +
    'Bn4lg3213n0sPgcJnlu22dL/N/mvG2wCuJr5jQY48NoAAAAASUVORK5CYII=',
    // shape (tshape)
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAA7DAAAOwwHHb6hkAAAA' +
    'GXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAAAjhJREFUSInNlV9LU2Ecxz/Ps7O/' +
    'GulikThjNudql3VtIzUy77pQoYugC1n4FmJo70DoIrsMurFewJCg9RIiQibqnChZ5JhZ+3fO3NPF' +
    '1G3oOmfCoC88N8/5ff+dh/McoZSik5AdVW/bYC++yF58sR2KsPyKfr64hlFJA2DXbuCb/26FZr2B' +
    'bsTRtwR6RqIbcas0aw1O0h8k3AgFlyeLHGlDDMx/M6Naa3CSXhWhWgI9I5HGcytU8waN6VXxOJbL' +
    'cgvzBo3pT9BGi6YGiQ2c+iFz5aqKOTUGEeAgq4XlGxmQb5HoDdGstTg1SHzBX6io5HaWvmSKrt2D' +
    '2oC/Bx5ECoR694k6n+LiR53tvgO525DuP6tcrf5hZuaSUEqR2MBZOFRfP62JwMeU0s5Lcj9yxOTw' +
    'DuOOR0iMegv3BDxZgWyxmbCwAFNTQgLoh8xtZ+lrJQ7wYdXGeu4qGTXTkLIERgYeh1vRaodcrqpY' +
    'co2ullPHWFn1sK5PN29WUjARgCvu1gZOjcHdnJk87ORAl/7mTZMWGoAQWLqQJICQ4J0++zBagJef' +
    'zzcoGWT8PYTT+/826O8Fe74A4++s5KmH8mji1egt8mbDozdVfjiftix+amDrZum6l72xiKi0GhyP' +
    'iMqAV+wGfl3A4OEQZY8m7kVDamt2hHzQBw6ttoI+mB1R+bshtem0iTGpqm0ZNF0V71dxuCs8Kxgq' +
    '5tIIApR0Nt0OsVSy83oqgs7y8m+k7DZVbvySO4n/7Kd/AfwF9G3x/HYIj78AAAAASUVORK5CYII=');

////////////////////////////////////////////////////////////////////////////////
procedure LoadMdIcons(AList : TImageList);
var
  I   : TMdIcon;
  Bmp : TBitmap;
begin
  AList.Width:=16;
  AList.Height:=16;
  for I:=Low(TMdIcon) to High(TMdIcon) do
  begin
    Bmp:=LoadPNGBitmap(Icons[I]);
    try
      AList.Add(Bmp,nil);
    finally
      Bmp.Free;
    end;
  end;
end;

function PaletteGlyph(T : TMdType) : TBitmap;
begin
  if Glyphs[T]='' then Result:=nil else Result:=LoadPNGBitmap(Glyphs[T]);
end;

end.
