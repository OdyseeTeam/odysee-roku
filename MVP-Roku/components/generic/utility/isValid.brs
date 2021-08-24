Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
    Return Type(value) <> "<uninitialized>" And value <> invalid
End Function