# use rnn_diet.jl to define a function to import the data, then put an include statement at the top of this one.

module Runner

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Statistics: mean
using Random: shuffle
using Parameters: @with_kw

 # /Users/austinbean/Desktop/programs/emr_nlp
include("./punctuation_strip.jl")
include("./s_split.jl")
include("./rnn_diet.jl")


"""
`build_model(args)`
Takes as an argument the parameters in the "args" type.  
Returns two things: a 'scanner' and an 'encoder'.  
Dimension of the input needs to be # of unique words, 
so Dense(args.inpt_dim) takes an 'args.inpt_dim' type 
argument, where in LoadData() this is updated to the number of words.  
This is passed back after updating w/in the LoadData() function.
"""
function build_model(args)
	scanner = Chain(Dense(args.inpt_dim, args.N, σ), LSTM(args.N, args.N))
	encoder = Dense(args.N, 1, identity) # regression task - sum outputs and apply identity activation.
	return scanner, encoder 
end 



"""
`model(x, scanner, encoder)`
Scanner is applied to the data sequentially, then I take the LAST element.
so need to make sure scanner outputs a vector, since that is the input to encoder.
Needs to output args.N x 1 vector if the encoder is to make sense.
NB: must call reset!(scanner) after each call to scanner.  
Otherwise creates a matrix which is not conformable w/ later data elements.
	Question: which matrix?  Why?  
the number of COLUMNS created is: N_words x Dim_hidden state.  So I want the last **column**.  
Flux one-hot matrix has a field called data, which is an array of one-hot vectors. 
so this DOES matter
Accessing via .data seems to change the dims?  Doing scanner.(x.data) returns an array of 
N_elements rows and N_hidden_dim columns.  Then taking scanner.(x.data)[end] returns the LAST 
one of these rows, which is what I want.  
Note then you have to take encoder(state)[1] to access the scalar in the 1x1 record.
Otherwise an error in loss b/c you can't do: [float] - float.
"""
function model(x, scanner, encoder)
	state = scanner.(x.data)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)[1]                 # this returns a vector of a single element...  annoying.  
end 






function RunIt()
    test_data, train_data, argg = LoadData() # words, labels will be loaded
	@info("Constructing Model...")
	scanner, encoder = build_model(argg)     # NB: scanner and encoder have to be created first.  
	loss(x, y)=  (model(x, scanner, encoder) - y)^2
	testloss() = mean(loss(t...) for t in train_data)
	opt = ADAM(argg.lr)
	ps = params(scanner, encoder)
	evalcb = () -> @show testloss()
	for i = 1:50
		Flux.train!(loss, ps, train_data, opt, cb = throttle(evalcb, argg.throttle))
    end 
    # next step... predict, distribution of predictions, etc.  
end 

RunIt()

end 