# duplicate stata regexes...

#=

Julia standard: http://www.pcre.org/current/doc/html/pcre2syntax.html

need to get matches, then replace or substitute or whateve.

	keep note_text visit_id //gen text_comp = note_text 
	* rewrite this to introduce spaces around some punctuation marks. 
	replace note_text = lower(note_text) 
	* Here need to do this with USTR regexes. 

	* handle annoying strings of question marks. 
	replace note_text = ustrregexra(note_text, "\?{2,}", "?") // sequences of ? down to 1 
	replace note_text = ustrregexra(note_text, "\?", " ") // remove all single ? 
	replace note_text = subinstr(note_text, "?", "", .) // this is just a check - doesn't end up doing anything. 
	
	* remove times: 
	replace note_text = regexr(note_text, "[0-9]+:[0-9]+", "XTIMEX") 

	* remove dates: 
	replace note_text = ustrregexra(note_text, "(0[1-9]|1[012]|[1-9])[-/ \.]([1-9]|0[1-9]|[12][1-9]|3[01])[-/ \.](0[0-9]|1[1-9]|[20][01][0-9]|9[0-9])", "XDATEX") // this doesn't get 1999 dates quite right, but there shouldn't be any. 

	* remove '-' among numbers 
	replace note_text = ustrregexra(note_text, "-{2,}", "-", .) 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])-(?=[0-9])", " to ") 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])-", " ") 
	replace note_text = ustrregexra(note_text, "-(?=[0-9])", " ") 

	* remove - among words 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z])-(?=[A-Za-z])", " ") 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z]-(?=[0-9]))", " ") 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])-(?=[A-Za-z])", " ") 
	replace note_text = ustrregexra(note_text, "-(?=[A-Za-z])", " ") 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z])-", " ") 

	* periods at the end of sentences with no spaces 
	* gets most of them. 
	replace note_text = ustrregexra(note_text, "\.{2,}", "\.") 
	replace note_text = ustrregexra(note_text, "(?<!\d)\.(?!\d)", " ") // period w/ no space -> "look backwards" AND "look forwards" regexes \d is decimal digits, so this is *not* those 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z])\.(?=\d)", " ") 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])\.(?=[A-Za-z])", " ") 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])\.(?=\s)", " ") 

	* drop / in words -> not sure I really care whether it's in numbers or words 
	replace note_text = ustrregexra(note_text, "/", " ") 
	//ustrregexra(note_text, "(?<![0-9])/(?![0-9])", " ") 
	replace note_text = ustrregexra(note_text, "\\", " ") 

	* add a space after a number. 
	replace note_text = ustrregexra(note_text, "(?<=[0-9])(?=[A-Za-z])", " ") 

	* add a space before a number, BUT NOT BEFORE V 
	replace note_text = ustrregexra(note_text, "(?<=[A-UW-Za-uw-z])(?=[0-9])", " ") // EXCLUDE V for V-CODES 

	* fix lettercommaletter w/ no space 
	replace note_text = ustrregexra(note_text,	"(?<=[A-Za-z]),(?=[A-Za-z])", " ") 

	* replace %ile with % 
	replace note_text = ustrregexra(note_text, "%ile", "%") 
	* punctuation 
	replace note_text = subinstr(note_text, "@", " ", .) 
	replace note_text = subinstr(note_text, "#", " ", .) 
	replace note_text = subinstr(note_text, ">", " ", .) 
	replace note_text = subinstr(note_text, "<", " ", .) 
	replace note_text = subinstr(note_text, "{", " ", .) 
	replace note_text = subinstr(note_text, "}", " ", .) 
	replace note_text = subinstr(note_text, ":", " ", .) 
	replace note_text = subinstr(note_text, ",", " ", .) 
	replace note_text = subinstr(note_text, ";", " ", .) 
	replace note_text = subinstr(note_text, "+", " ", .) 
	replace note_text = subinstr(note_text, "(", " ", .) 
	replace note_text = subinstr(note_text, ")", " ", .) 
	replace note_text = subinstr(note_text, "!", " ", .) 
	replace note_text = subinstr(note_text, "[", " ", .) 
	replace note_text = subinstr(note_text, "]", " ", .) 
	replace note_text = subinstr(note_text, "*", " ", .) 
	replace note_text = subinstr(note_text, "=", " ", .) 
	* apostrophes are below. 
	* need to remove " too 
	replace note_text = ustrregexra(note_text, `"""', "" ) // requires double quoting with ` and " simultaneously 
	replace note_text = subinstr(note_text, "&", " and ", .) 
	* replace n spaces with single spaces: 
	replace note_text = ustrregexra(note_text, " {2,}", " ", .) 
	* replace n underscores with a single space 
	replace note_text = ustrregexra(note_text, "_{2,}", " ", .) 
	* possessives 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z])'s", "") 
	replace note_text = ustrregexra(note_text, "(?<=[A-Za-z])`s", "") // someone does it with the other apostrophe? * cut out apostrophes 


	replace note_text = subinstr(note_text, "'", "", .)
=#



function string_cleaner(x::String)
		# replace(x, r""=>"")
		# question marks
	x = replace(x, r"\?{2,}"=>"?")
	x = replace(x, r"\?"=>" ")
	x = replace(x, r"-{2,}"=>"-")
		# dashes
	x = replace(x, r"(?<=[0-9])-(?=[0-9])"=>" to ") # positive lookbehind and positive lookahead to replace single - w/ " to "
	x = replace(x, r"(?<=[0-9A-Za-z])-"=>" ")
	x = replace(x, r"-(?=[0-9A-Za-z])"=>" ")
		# periods 
	x = replace(x, r"\.{2,}"=>".")
	x = replace(x, r"(?<!\d)\.(?!\d)"=>"")
	return x
end




	# TESTS.
test1 = "something??? with? a long???? set of???strings??? of question??? marks????"
test2 = "some--times there are ---- long strings ?--- ??? ?  --- "
test3 = "want. ...to r.....emove 2--5-word word-2----6 2-6 10 --- 41 --19----3-3-3-3-3"
test4 = "v.345 v.v 3.6 7.v 8.w w.9 "

# run tests
string_cleaner(test1)
string_cleaner(test2)
string_cleaner(test3)
string_cleaner(test4)




