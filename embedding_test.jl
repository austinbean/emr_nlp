# embeddings_tests

include("/Users/austinbean/Desktop/programs/emr_nlp/rnn_embeddings.jl")

embtable = load_embeddings(Word2Vec)




# these all look right... 
v1 = unique(embtable.vocab)
L = Embed(v1, 6, embtable)
L2 = Embed(v1, 7, embtable)
L3 = Embed(v1, 3, embtable, identity)
L3.E*onehotbatch(["in", "for", "that"], v1)

#=
L3.E*onehotbatch(["in", "for", "that"], v1)
3×3 Array{Real,2}:
 0.0529562  -0.00851202  -0.0123606
 0.0654598  -0.0342245   -0.0222299
 0.0661953   0.0322839    0.0655398

TODO - take this and run it through the RNN.  

Chain(Embed(v, 100), LSTM(100, 100), Dense(100, 1, identity))
 =#

 scanner = Chain(Embed(v1, 128, embtable), LSTM(128, 128), LSTM(128, 128) )
 encoder = Dense(128, 1, identity)
  

 test1 = onehotbatch(["the", "for", "that", "because", "why"], v1)

    # below line works as scanner = Chain(Embed(v1, 128, embtable), LSTM(128, 128), LSTM(128,128) )
    # this seems to work now w/ a similar arrangement to the RNN.  
 state = scanner.(test1.data)[end]  
 reset!(scanner)
 encoder(state)

  #=
from the other file:
	state = scanner.(x.data)[end]     # the last column, so the last hidden state and feature.  
	reset!(scanner)                   # must be called before each new record
	encoder(state)[1]                 # this returns a vector of a single element...  annoying.  

 =#