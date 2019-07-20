# using the output of train_embedding.jl, try to train a network.
# https://github.com/FluxML/model-zoo/blob/master/text/lang-detection/model.jl
# cd /Users/austinbean/Desktop/programs/emr_nlp

using CSVFiles, Flux, DataFrames


dat1 = DataFrame(load("embedded_data.csv"));

# the model for is Wx .+ b,
# Note that `target` is a row vector N_{obs} × 1
# Want: Wx.+b to be... N_{obs} × 1
# W is (1) × (features)
# x is (features) × N_{obs}
# b is N_{obs} × 1

    # Let this be a ROW vector of N_{obs} × 1
target = convert(Array{Float32,1}, dat1[:x1]);
target = transpose(target);
    # this should be 1 × ≈ 5,000

inp1 = convert(Array{Float32,2}, dat1[:,[:x2, :x3, :x4, :x5, :x6, :x7, :x8, :x9, :x10, :x11, :x12, :x13, :x14, :x15, :x16, :x17, :x18, :x19, :x20, :x21, :x22]])

inpt = transpose(inp1);
    # so inpt should be 21 × ≈ 5,000
    # inpt must be reshaped to four-dimensional to use CNN
inpt2 = reshape(inpt, (21,1,1,4961))

#train, test = dat1[1:end-500,:], dat1[end-500+1:end, :]


# TODO - CNN layer.
# need to be more careful specifying output dimensions!
    # what is required is a reshape of input so that it has dims d_{1} × d_{2} × d_{3} × d_{4}
    # requires a reshape again to work...
mod1 = Chain(
    Dense(10, 5, σ)
    )

mod1(inpt)


loss(x,y) = Flux.mse(mod1(x), y)
opt = ADAM(0.01)

Flux.train!(loss, Flux.params(mod1), [(inpt, target)], opt)

# basically works, at least for the simple version.
# Next step: using the CNN
# https://fluxml.ai/Flux.jl/stable/models/layers/#Convolution-and-Pooling-Layers-1
# Conv( size, in -> out, activation)
# eg., (21,1), 1=> 10, relu... maybe that would work?

# CNN -
    # note from docs that the input must be in "WHCN order (width, height, # channels, # batches)", in other words, input needs to
    # be reshaped to have dimension 4.
nfeat, mlen = size(inpt) # should be ≈ 21 × 5,000
inpt2 = reshape(inpt, (nfeat,1,1,mlen))


# what options work for input window size (x,y)...  The first dimension x in (x,y) can be increased up to 21
    # both dimensions of pad can be increased quite a bit ->
        # but the first dimension corresponds to the dimension of the actual data (i.e., 21 features)
        # the second dimension can probably be increased... given what?
    # the input dimension x of x=>y must match the number of channels, so 1 in this case (though could add more)
    # the output dimension y of x=>y can be increased quite a bit.
    # y also controls the 'third' dimension of the final output, e.g., 24 × 1 × y × 5000
    # there are stride and dilation arguments too.
mod2 = Chain(
    Conv((4,1), 1=>5, pad = (3,0), relu)
    )
# note that the output dimension is determined by input dimension and padding.
# Test...  the second dimension of this is 3 when the dimension of pad is (3,1) -> why?
    # it is determined by the second dimension of the pad, which can be set to 0
mod2(inpt2)

# newloss
loss_c(x,y) = Flux.mse(mod2(x), y)
opt = ADAM(0.01)

Flux.train!(loss_c, Flux.params(mod2), [(inpt2, target)], opt)


# try sequential CNN layers (is that necessary?)
    # what currently doesn't work: using maxpool or meanpool to reduce the dimensions.
    # in the example w/ MNIST there is a Maxpool operation here which reduces the dimension
    # https://github.com/FluxML/model-zoo/blob/master/vision/mnist/conv.jl
        # the second argument to maxpool should be the "pooldims"
        # pooldims can take as an argument... something?

mod3 = Chain(
    Conv((3,1), 1=>5, pad = (3,0), relu),
    #x -> maxpool(x, (1,1) ),
    Conv((2,1), 5=>1,pad = (2,0),relu),
    # reshape from 4-d to 2-d
    x -> reshape(x, (size(x)[1], size(x)[4])),
    # reduce this to one scalar per observation, so sum the ≈ 20 items
    x -> sum(x, dims = 1)
    )

mod3(inpt2)

loss_d(x,y) = Flux.mse(mod3(x), y)
opt = ADAM(0.01)

Flux.train!(loss_d, Flux.params(mod3), [(inpt2, target)], opt)


# next step... try training and seeing what happens to accuracy
    # maybe this model: https://github.com/FluxML/model-zoo/blob/master/vision/mnist/conv.jl



#
