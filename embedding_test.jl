# embeddings_tests

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Embeddings
using Embeddings: EmbeddingTable 
using Functors
using Statistics: mean
using Random: shuffle
using Parameters: @with_kw


include("/Users/austinbean/Desktop/programs/emr_nlp/rnn_embeddings.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/punctuation_strip.jl")
include("/Users/austinbean/Desktop/programs/emr_nlp/s_split.jl")



    # TODO - the issue is that the Embed layer is made w/ ALL of the words in the vocab,
    # not just the words I need (which appear in the data), so the matrices are not conformable.  


@with_kw mutable struct Args
    lr::Float64 = 1e-3        # learning rate
    V::Array{String} =[]      # the vocabulary
    E::Embeddings.EmbeddingTable = EmbeddingTable(zeros(2,2), zeros(3)) # has to be initialized w/ something.
    N::Int = 100              # Number of perceptrons in hidden layer - free parameter
    ed::Int = 20              # Embeddings dimension (up to 300 for word2vec)
	throttle::Int = 5         # throttle timeout
	test_d::Int = 300         # length of the testing set.
end




"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

"""
function LoadData()
		# Load and clean 
	xfile = CSV.read("/Users/austinbean/Desktop/programs/sumr2020/very_fake_diet_data.csv");
	words = convert(Array{String,1}, filter( x->(!ismissing(x))&(isa(x, String)), xfile[!, :Column1]));
	words = string_cleaner.(words) ;	      # regex preprocessing to remove punctuation etc. 
	mwords = maximum(length.(split.(words)))
	words = map( x->x*" <EOS>", words) ;   # add <EOS> to the end of every sentence.
    labels = filter( x-> !ismissing(x), xfile[!, :Column2]);
		# create an instance of the type
    args = Args()
    
        # Load the word embeddings and return the args type w/ that field updated.
    embtable = load_embeddings(Word2Vec)
    args.E = embtable
		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
    args.V =  unique(allwords)
    interim = map( v -> Flux.onehotbatch(v, allwords, "<UNK>"), s_split.(words)) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
	all_data = [(x,y) for (x,y) in zip(interim,labels)] |> shuffle                      # pair data and labels, then randomize order
		# separate test data and train data 
	train_data = all_data[1:end-args.test_d]
	test_data = all_data[end-args.test_d+1:end]
		# Return args b/c nwords may have been updated.
	return train_data, test_data, args
end 



"""
`build_model(args)`
Embed(vocab::AbstractArray, d::Int, emtab)
"""
function build_model(args)
	scanner = Chain(Embed(args.V, args.ed, args.E), LSTM(args.ed, args.N), LSTM(args.N, args.N))
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
    @info("Loading Data...")
    test_data, train_data, argg = LoadData() # words, labels will be loaded
	@info("Constructing Model...")
    scanner, encoder = build_model(argg)     # NB: scanner and encoder have to be created first.  
	loss(x, y)=  (model(x, scanner, encoder) - y)^2
	testloss() = mean(loss(t...) for t in train_data)
	opt = ADAM(argg.lr)
	ps = params(scanner, encoder)
	evalcb = () -> @show testloss()
	for i = 1:5
		Flux.train!(loss, ps, train_data, opt, cb = throttle(evalcb, argg.throttle))
    end 
    # next step... predict, distribution of predictions, etc.  
end 

RunIt()











#=
# these all look right... 
v1 = unique(embtable.vocab)
L = Embed(v1, 6, embtable)
L2 = Embed(v1, 7, embtable)
L3 = Embed(v1, 3, embtable, identity)
L3.E*onehotbatch(["in", "for", "that"], v1)

L3.E*onehotbatch(["in", "for", "that"], v1)
3×3 Array{Real,2}:
 0.0529562  -0.00851202  -0.0123606
 0.0654598  -0.0342245   -0.0222299
 0.0661953   0.0322839    0.0655398


 =#
