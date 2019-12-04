# duplicate stata regexes...

#=

Julia standard: http://www.pcre.org/current/doc/html/pcre2syntax.html
	X replace note_text = subinstr(note_text, "?", "", .) // this is just a check - doesn't end up doing anything. 
	
		* remove '-' among numbers 
	replace note_text = ustrregexra(note_text, "-{2,}", "-", .) 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])-(?=[0-9])", " to ") 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])-", " ") 
	replace note_text = ustrregexra(note_text, "-(?=[0-9])", " ") 

	* need to remove " too 
	X replace note_text = ustrregexra(note_text, `"""', "" ) // requires double quoting with ` and " simultaneously 


	replace note_text = subinstr(note_text, "'", "", .)
=#



function string_cleaner(x::String)
		# replace(x, r""=>"")
	x = lowercase(x)
		# question marks
	x = replace(x, r"\?{2,}"=>"?")
	x = replace(x, r"\?"=>" ")
	x = replace(x, r"-{2,}"=>"-")
		# times 
	x = replace(x, r"[0-9]+:[0-9]+"=>"XTIMEX")
		# dates ⇒ doesn't quite get 1999 or -9 ending dates right.
	x = replace(x, r"(0[1-9]|1[012]|[1-9])[-/ \.]([1-9]|0[1-9]|[12][1-9]|3[01])[-/ \.](0[0-9]|1[1-9]|[20][01][0-9]|9[0-9])" => "XDATEX")
		# dashes
			# this doesn't get - => to when surrounded by spaces
	x = replace(x, r"(?<=[0-9])-(?=[0-9])"=>" to ") # positive lookbehind and positive lookahead to replace single - w/ " to "
	x = replace(x, r"(?<=[0-9A-Za-z])-"=>" ")
	x = replace(x, r"-(?=[0-9A-Za-z])"=>" ")
	x = replace(x, r"(?<=[A-Za-z])-(?=[A-Za-z])"=>" ")
	x = replace(x, r"(?<=[A-Za-z]-(?=[0-9]))"=>" ")
	x = replace(x, r"(?<=[0-9])-(?=[A-Za-z])"=>" ")
	x = replace(x, r"-(?=[A-Za-z])"=>" ")
	x = replace(x, r"(?<=[A-Za-z])-"=>" ")
	x = replace(x, r" - "=>" to ")
		# periods 
	x = replace(x, r"\.{2,}"=>".")
	x = replace(x, r"(?<!\d)\.(?!\d)"=>"")
	x = replace(x, r"(?<=[A-Za-z])\.(?=\d)"=>" ")
	x = replace(x, r"(?<=[0-9])\.(?=[A-Za-z])"=>" ")
	x = replace(x, r"(?<=[0-9])\.(?=\s)"=>" ")
		# slash 
	x = replace(x, r"/{1,}"=>" ")
		# spaces after numbers: 
	x = replace(x, r"?<=[0-9])(?=[A-Za-z])"=>" ")
		# spaces before numbers, but beware v-codes 
	x = replace(x, r"(?<=[A-UW-Za-uw-z])(?=[0-9])"=>" ")
		# letter comma letter w/ no spaces 
	x = replace(x, r"(?<=[A-Za-z]),(?=[A-Za-z])" => " ")
		# %-ile to %
	x = replace(x, r"%ile"=>"%") # %-ile may be missed.
		# other punctuation
	x = replace(x, r"@"=>" ")
	x = replace(x, r"#"=>" ")
	x = replace(x, r">"=>" ")
	x = replace(x, r"<"=>" ")
	x = replace(x, r"{"=>" ")
	x = replace(x, r"}"=>" ")
	x = replace(x, r":"=>" ")
	x = replace(x, r","=>" ")
	x = replace(x, r";"=>" ")
	x = replace(x, r"+"=>" ")
	x = replace(x, r"("=>" ")
	x = replace(x, r")"=>" ")
	x = replace(x, r"!"=>" ")
	x = replace(x, r"["=>" ")
	x = replace(x, r"]"=>" ")
	x = replace(x, r"*"=>" ")
	x = replace(x, r"="=>" ")
	x = replace(x, r"&"=>" and ")
	x = replace(x, r"_{2,}"=>" ")
		# multiple spaces
	x = replace(x, r" {2,}"=>" ")
		# both apostrophes 
	x = replace(x, r"(?<=[A-Za-z])'s"=>"")
	x = replace(x, r"(?<=[A-Za-z])`s"=>"")

	return x
end



	# TESTS.
test1 = "something??? with? a long???? set of???strings??? of question??? at 9:15 15:05 11:1 1:1 on 3/5/15 03/21/2019 6/2/1999 06/1/15 3/04/2019 "
test2 = "some--times there are ---- long strings ?--- ??? ?  --- "
test3 = "want. ...to r.....emove 2--5-word word-2----6 2-6 10 --- 41 --19----3-3-3-3-3"
test4 = "v.345 v.v 3.6 7.v 8.w w.9 1 - 5 1- 6 2 -3 3-6 ounces of Enfamil"
test5 = ""

# run tests
string_cleaner(test1)
string_cleaner(test2)
string_cleaner(test3)
string_cleaner(test4)

starr1 = [test1; test2; test3; test4]

string_cleaner.(starr1)



