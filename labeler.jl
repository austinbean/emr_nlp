"""
`labeler(x)`
Generates some labels (1-5) from numerical values.
 0 < x ≤ 20 ⇒ 1
20 < x ≤ 30 ⇒ 2
30 < x ≤ 40 ⇒ 3
40 < x ≤ 50 ⇒ 4 
50 < x ≤  ∞ ⇒ 5
"""
function labeler(x)
	outp = hcat(x, zeros(size(x,1),1))
	for i = 1:size(x,1)
		if outp[i,1] <= 20 
			outp[i,2] = 1			
		elseif (outp[i,1] > 20) & (outp[i,1]<= 30)
			outp[i,2] = 2
		elseif (outp[i,1] > 30) & (outp[i,1] <= 40)
			outp[i,2] = 3
		elseif (outp[i,1] > 40) & (outp[i,1] <= 50) 
			outp[i,2] = 4
		else 
			outp[i,2] = 5
		end 
	end 
	return outp
end 

"""
`PadSentence(str, dmax)`
Adds "<EOS>" as a string up to the end of the string `str` so 
its length is equal to `dmax`
"""
function PadSentence(str, dmax)
    l = length(split(str))
    pad = dmax - l 
    if (pad > 0)
        return str*repeat(" <EOS>", pad)
    else 
        return str 
    end 
end 
