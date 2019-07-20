
using CSVFiles, Flux, DataFrames, Random, Printf, Statistics
Random.seed!(1)

dat1 = DataFrame(load("embedded_data.csv"));
    # permute rows randomly
dat1 = dat1[Random.shuffle(1:end),:];

# select out a fraction as test...
nr, nc = size(dat1);
    # split is 70/20/10
tr = convert(Int64, floor(0.7*nr));
vl = convert(Int64, floor(0.9*nr));
    # split the data
tr_dat = dat1[1:tr,:];
vl_dat = dat1[(tr+1):vl,:];
ts_dat = dat1[(vl+1):end,:];

# for the training data
        # Let this be a ROW vector of N_{obs} × 1
    target = convert(Array{Float32,1}, tr_dat[:x1]);
    target = transpose(target);

    inp1 = convert(Array{Float32,2}, tr_dat[:,[:x2, :x3, :x4, :x5, :x6, :x7, :x8, :x9, :x10, :x11, :x12, :x13, :x14, :x15, :x16, :x17, :x18, :x19, :x20, :x21, :x22]])
    inpt = transpose(inp1);
    tr, tc = size(inpt)
        # so inpt should be 21 × ≈ 5,000
        # inpt must be reshaped to four-dimensional to use CNN
    inpt2 = reshape(inpt, (tr,1,1,tc))

# for the validation data
    v_targ = convert(Array{Float32,1}, vl_dat[:x1]);
    v_targ = transpose(v_targ);

    v_inp = convert(Array{Float32,2}, vl_dat[:, [:x2, :x3, :x4, :x5, :x6, :x7, :x8, :x9, :x10, :x11, :x12, :x13, :x14, :x15, :x16, :x17, :x18, :x19, :x20, :x21, :x22]])
    v_inp = transpose(v_inp);
    vtr, vtc = size(v_inp);
    v_in = reshape(v_inp, (vtr,1,1,vtc));

# Model -
    # here we can do different
        # more layers, different strides, etc.
        # TODO - better understanding of what "pad" does w/ a zero dimension
        # TODO - add more conv. layers
        # TODO - try concatenating different strides?  


mod3 = Chain(
    Conv((3,1), 1=>5, pad = (3,0), relu),
    #x -> maxpool(x, (1,1) ),
    Conv((2,1), 5=>1,pad = (2,0),relu),
    # reshape from 4-d to 2-d
    x -> reshape(x, (size(x)[1], size(x)[4])),
    # reduce this to one scalar per observation, so sum the ≈ 20 items
    x -> sum(x, dims = 1)
    )

    # call the model once
mod3(inpt2)

loss_d(x,y) = Flux.mse(mod3(x), y)

@info( @sprintf("Initial MSE: %.4f ", loss_d(inpt2, target) ))

opt = ADAM(0.01)

Flux.train!(loss_d, Flux.params(mod3), [(inpt2, target)], opt)

    # is there any need for a separate accuracy function...?

best_acc = 0.0
improvement = 0.0

for ep_ix in 1:100
    global best_acc, improvement

    Flux.train!(loss_d, Flux.params(mod3), [(inpt2, target)], opt)


    # what is the MSE on the validation data?  -> is MSE the best summary?
        # could also do: how many get within: 1, 2, 3, 4, 5, 6 ounces of correct ans.
    # acc = loss_d(v_in, v_targ)
    acc = mean( abs.(mod3(v_in).- v_targ) )
    #@info(@sprintf("[%d]: Test accuracy: %.4f", ep_ix, acc))

    # another accuracy measure.
    nt = size(v_targ)[2]
    acc_1 = sum(abs.(mod3(v_in).-v_targ).<= 1)/nt
    acc_5 = sum(abs.(mod3(v_in).-v_targ).<= 5)/nt
    acc_10 =  sum(abs.(mod3(v_in).-v_targ).<= 10)/nt
    acc_sd = sum(abs.(mod3(v_in).-v_targ).<= std(v_targ))/nt

    @info( @sprintf("[%d] - Within 1: %.2f, Within 5: %.2f, Within 10: %.2f, Within 1 SD: %.2f  ", ep_ix, acc_1, acc_5, acc_10, acc_sd ))

    # if acc <= best_acc
    #     @info("new best accuracy epoch %d", ep_ix)
    #     best_acc = acc
    #     improvement = ep_ix
    # end

end



#
