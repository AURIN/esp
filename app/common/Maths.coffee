@Maths =
  
  interpolateRatio: (a, b, ratio) -> a + ratio * (b - a)

  calcUniformBinValue: (bins, input, maxInput) ->
    binCount = bins.length
    throw new Error('Must have non-empty array of bins.') unless binCount > 0
    binSize = maxInput / binCount
    binFloat = input / binSize
    lowerBinIndex = Math.floor(binFloat)
    upperBinIndex = Math.ceil(binFloat)
    binRatio = binFloat - lowerBinIndex
    lowerBinValue = bins[lowerBinIndex]
    upperBinValue = bins[upperBinIndex]
    if !lowerBinValue? && !upperBinValue?
      null
    else if !lowerBinValue?
      upperBinValue
    else if !upperBinValue?
      lowerBinValue
    else
      Maths.interpolateRatio(lowerBinValue, upperBinValue, binRatio)
