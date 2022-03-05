Function IsValid(value As Dynamic) As Boolean 'TheEndless Roku Development forums
  try
    Return Type(value) <> "<uninitialized>" And value <> invalid
  catch e
    return false
  end try
End Function