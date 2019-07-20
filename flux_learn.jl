
# try something even simpler...

# note that the order is W*x .+ b ->
# bias must be cases × 1, so, e.g., N_{units} × 1
# that means Wx must be N_{units} × 1.
# so x is N_{features} × N_{units} -> each column must be an observation.
# W is N_{features}


using Flux

model = Dense(21, 10, sigmoid)
loss_f(x,y) = Flux.mse(model(x), y)
opt = ADAM(0.1)

inp_data = rand(21,)
out_labs = transpose(rand(1:4, 50))

loss_f(inp_data, out_labs)
    # this syntax works.
Flux.train!(loss_f, Flux.params(model), [(inp_data, out_labs)], opt)


# the conv layer
    # the complaint about the dimension mismatch is from the dimensions of inp_data.
    # rand(21, ) has dim 1, rand(21, 50) has dim 2... etc.  Needs as many dimensions as W, which has four.
inp_data = rand(21,50, 3, 100)
model = Conv((2,1), 3=>5, relu)
model(inp_data)
