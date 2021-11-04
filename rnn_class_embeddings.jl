# rnn_classification

#=

which patients use formula, breast, both, no information.
Simple task, but good proof of concept, perhaps.

TODO - LSTM may not work if some of the inputs are Float64 
Probably the embeddings are in Float64 form.   

=#

module Run_Class_Embeddings

using CSV 
using DataFrames
using Query 
using Flux
using Flux: onehot, onehotbatch, throttle, reset!
using Statistics: mean
using Random: shuffle, seed! 
using Parameters: @with_kw
using Plots 
using Tables 
using Embeddings
using Embeddings: EmbeddingTable
using Functors
using Dates 

 # /Users/austinbean/Desktop/programs/emr_nlp
include("./punctuation_strip.jl")
include("./s_split.jl")
include("./rnn_embeddings.jl")
include("./labeler.jl")

#include("/home/beana1/emr_nlp/punctuation_strip.jl")
#include("/home/beana1/emr_nlp/s_split.jl")
#include("/home/beana1/emr_nlp/rnn_embeddings.jl")



@with_kw mutable struct Args
    lr::Float64 = 1e-3      # learning rate
	inpt_dim::Int  = 813    # number of words.  size(allwords,1)
	N::Int = 48            # Number of perceptrons in hidden layer - free parameter
	throttle::Int = 1       # throttle timeout
    test_d::Int = 600       # length of the testing set.
    classes::Int = 3        # how many classes are there?
    emb_table::Embeddings.EmbeddingTable = EmbeddingTable(zeros(2,2), zeros(3)) # has to be initialized w/ something later
    embed_len::Int = 50    # Length of vector per each word embedding
    test_len::Int = 100    # Number of unique words in test data 
    # TODO - likely deletable.  Is this used anywhere important?  Duplicates inpt_dim 
    word_list_len::Int = 0 # Total number of unique words
    vocab::Array{String, 1} = []  #All the words in the training data
end

"""
`PadSentence(str, dmax)`
Adds the pattern " <blank>" to sentences which are less than `dmax`
long up to the length `dmax`.
"""
function PadSentence(str, dmax)
    l = length(split(str))
    pad = dmax - l 
    if (pad > 0)
        return str*repeat(" <blank>", pad)
    else 
        return str 
    end 
end 


"""
`LoadData()`

This creates test and training data and returns them.  Also returns an instance of 'args' type
w/ the number of unique words in the data updated.

# test of filter statement below.  
df = DataFrame(diet_text=["hi", missing, "bye"], total_formula=[missing, 1, 2])
# should be ["bye", 2] and it is.  
"""
function LoadData()
	seed!(0) # for shuffle
		# Load the text
	xfile = CSV.read("/Users/austinbean/Desktop/diet_local/formula_subset.csv", DataFrame);	 
	#	xfile = CSV.read("/home/beana1/emr_nlp/class_label.csv", DataFrame);
		# Shuffle DataFrame rows, making a copy  
	xfile = xfile[shuffle(1:size(xfile, 1)),:]
		# this filter must check whether :diet_text is not missing AND whether :total_formula is not missing.  
	xfile = filter(x-> (!ismissing(x[:diet_text])&(!ismissing(x[:total_formula])&(isa(x[:diet_text], String)))), xfile)
		# then subset out words separately.  
	num_sentences = size(xfile,1)
	words = convert(Array{String,1}, xfile[!, :diet_text]);
	words = string_cleaner.(words) ;	                                                # regex preprocessing to remove punctuation etc. 
		# this is the longest single sentence.
	mwords = maximum(length.(split.(words)))
	words = PadSentence.(words, mwords)
	words = map( x->x*" <EOS>", words) ;                                                # add <EOS> to the end of every sentence.
	# pad the sentences to max length 
	
	# create an instance of the type
	args = Args()

    	#Load the  word embeddings and assign back to args
    eTable = load_embeddings(GloVe)
    args.emb_table = eTable
    	# get the labels
	labels = labeler(xfile[!,:total_formula])[:,2] 
   		# collect all unique words to make 1-h vectors. 
	allwords = [unique( reduce(vcat, s_split.(words)) ); "<UNK>"]                       # add an "<UNK>" symbol for unfamiliar words
	nwords = size(allwords,1)                                                           # how many unique words are there?
	args.inpt_dim = nwords                                                              # # of unique words is dimension of input to first layer.
    args.vocab = allwords 
    e1 = Embed(allwords, args.embed_len, eTable)
		# subset test/train	
	test_ix = convert(Int64,floor(0.7*size(xfile,1)))
	training_data = MakeData(args.embed_len, args.vocab, e1, words[1:test_ix])
	test_data = MakeData(args.embed_len, args.vocab, e1, words[(test_ix+1):end])

		# one-hot batch the labels, then subset test/train 
    all_labels = [unique(labels); -1]                                                   # how many classes?
    args.classes = size(all_labels,1)     
    interim_labels = map( v-> Flux.onehot(v, all_labels, -1), labels)		
	train_labels = reshape(interim_labels[1:test_ix],1, size(interim_labels[1:test_ix],1))
	train_labels = hcat(train_labels...)
	test_labels = reshape(interim_labels[(test_ix+1):end],1, size(interim_labels[(test_ix+1):end],1))
	test_labels = hcat(test_labels...)
	return (training_data, train_labels), (test_data, test_labels), args
end 

"""
`MakeData`
Takes an embedding length, the set of all words, an embedding layer, the number 
of sentences, and a list of sentences and returns a Vector of Matrices, where 
the dimensions are: [ Embed_len × Number of sentences]_(N words in sentence)

 
(seq length == sentence length) × (features == length of embedding) × (number of sentences)
but as a vector, so [(features)×(number of sentences)]_(N_*words* in sentence × 1)
first reshape to (embed_dim × sentences)
probably all sentences must be padded.  
also this needs to be a vector.  For this example [50 x 533]_(85x1)

"""
function MakeData(embed_len, all_words, embed_layer, sentences)
	num_sentences = length(sentences)
    interim = embed_layer.(map( v -> Flux.onehotbatch(v, all_words, "<UNK>"), s_split.(sentences))) 		# this is just for readability - next line can be substituted for "interim" in subsequent 
	to_reshape = vcat(interim...)
	tens = reshape(to_reshape, (embed_len,num_sentences,:))
	data = Vector{Matrix{Float32}}()
	for i = 1:size(tens,3)
		push!(data, tens[:,:,i])
	end 
	return data 
end 

"""
DataBatch(train_data, train_label, 30)
"""
function DataBatch(d, labels, batch_size)
	num_sentences = size(d[1],2)
	remainder = num_sentences%batch_size 
	batches = num_sentences ÷ batch_size 
	if remainder > 0 
		batches += 1
	end 
	batched = Vector() # type Any...
	for i = 1:batches 
		ix_start = ((i-1)*batch_size+1)
		ix_end = min((i*batch_size), num_sentences) # in case there is a remainder
		tm_dat = Vector{typeof(d[1])}()
		tm_lab = Vector{typeof(labels[:,1])}()
		for k = 1:size(d,1) # 
			push!(tm_dat, d[k][:,ix_start:ix_end])
		end 
		for j = ix_start:ix_end 
			push!(tm_lab, labels[:,j])
		end 
		push!(batched, (tm_dat,hcat(tm_lab...)))
	end 
	return batched 
end 



"""
`two_layers(args)`
Removed the Embed layer to help with data prep.  
"""
function two_layers(args)
    scanner = Chain(LSTM(args.embed_len, args.N), LSTM(args.N, args.N))
    encoder = Dense(args.N, args.classes, identity)
	return scanner, encoder 
end 

"""
`model`
Dimension of single observation is:
(total # words in data) × (sentence length)
1.  Does the embedding layer work right?
Try this on a sentence of one word... 


make a test datum:
test_datum = Vector{Matrix{Float32}}()
for i = 1:80
	push!(test_datum, rand(Float32, 50,1))
end 

test_d2 = collect( eachslice( rand(Float32,50,1,80), dims=3))
model(test_d2, scanner, encoder)

[model([train_data[x][:,j] for x in 1:size(train_data,1)], scanner, encoder) for j = 1:size(train_data[1],2) ]

"""
function model(x, scanner, encoder)
	reset!(scanner)                   # must be called before each new record
	state = scanner(x[1]) 
	for i=2:length(x)                 # this is explicit about the order
		state = scanner(x[i])
	end 
	encoder(state)
end 

"""
debug sizes with this line: 
  Flux.Zygote.ignore() do  # Debugging purposes only. If this fails, check the shapes!
    @assert ndims(logits) == 2 && size(logits) == size(labels)
  end
"""
function overall_loss(data, labels, scanner, encoder)
  logits = model(data, scanner, encoder)
  Flux.logitcrossentropy(logits, labels)
end

"""

	for (x,y) in zip(train_data, train_label)  
		#loss(x,y)
		gs = Flux.gradient(ps) do 
			loss(x,y)
		end 
		Flux.update!(opt, ps, gs)
	end 

		for (x,y) in zip(b[1],b[2]) # tuple elements?
			gs = Flux.gradient(ps) do 
				overall_loss(x,y)
			end 
			Flux.update!(opt, ps, gs)
		end 
"""
function DoIt()
    seed!(323) 
	(train_data, train_label), (test_data,test_label),  argg = LoadData() # words, labels will be loaded
	opt = ADAM(argg.lr)
    epoc = 10
    scanner, encoder = two_layers(argg)       
    ps = params(scanner, encoder)   
	@info "initial loss value: " overall_loss(train_data, train_label, scanner, encoder) 
    testloss() = overall_loss(test_data, test_label, scanner, encoder)
	testloss()
	@info "trying again... "

		# This works but does not reduce the error.  
	batched = DataBatch(train_data, train_label, 30) # returns 12 batches
	ol(x,y) = overall_loss(x,y,scanner, encoder)
	for i = 1:epoc
		@info "Epoch" i
		for b in batched # each of these is a tuple 
			grads = Flux.gradient(ps) do 
				ol(b...)
			end 
			Flux.update!(opt, ps, grads)
			@show testloss()
		end 
	end 
	# record the predictions 
	#=	
	predictions = map(v -> v[2], findmax.(softmax.(submod.(test_data.data[1]))))
	ix_labels = map( v-> convert(Int64, v.ix), test_data.data[2])
	# save the predictions and the training error:
	filename = "RNEMCL_"*string(nlayers)*"_l_"*string(argg.N)*"_n_"*string(epoc)*"_e"*t2
	CSV.write("/home/beana1/emr_nlp/results/CE_"*filename*".csv", Tables.table(hcat( ["training_epoch"; collect(1:length(loss_v))],["loss_value"; loss_v])))
	CSV.write("/home/beana1/emr_nlp/results/CO_"*filename*".csv", Tables.table(hcat( ["predicted_class"; predictions], ["actual_label"; ix_labels] )) )
	=#
end 
DoIt()

end # of module 