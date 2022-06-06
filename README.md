### markov-melodies
Generate MIDI files using a [markov algorithm](https://en.wikipedia.org/wiki/Markov_algorithm).

### Example
The source code for this example can be found in [examples/sort.mmel](./examples/sort.mmel).
It sorts digits of the alphabet `{0, 1, 2, 3}` in ascending order, so `0132` will become `0123`.


This is the output when running it on the string `012300103020203101`:

```
~/D/P/markov-melodies (main)> ./zig-out/bin/mkv examples/sort.mmel -i=012300103020203101 -t 80 -v > /dev/null
Parsing took 0.041ms
'012300103020203101' -> '012300013020203101' : single(C3, 1)
'012300013020203101' -> '012300013020203011' : single(C3, 1)
'012300013020203011' -> '012300013002203011' : chord({E3, G4, A5}, 1)
'012300013002203011' -> '012300013002023011' : chord({E3, G4, A5}, 1)
'012300013002023011' -> '012300013000223011' : chord({E3, G4, A5}, 1)
'012300013000223011' -> '012030013000223011' : single(A2, 1)
'012030013000223011' -> '010230013000223011' : chord({E3, G4, A5}, 1)
'010230013000223011' -> '001230013000223011' : single(C3, 1)
'001230013000223011' -> '001203013000223011' : single(A2, 1)
'001203013000223011' -> '001023013000223011' : chord({E3, G4, A5}, 1)
'001023013000223011' -> '000123013000223011' : single(C3, 1)
'000123013000223011' -> '000120313000223011' : single(A2, 1)
'000120313000223011' -> '000102313000223011' : chord({E3, G4, A5}, 1)
'000102313000223011' -> '000012313000223011' : single(C3, 1)
'000012313000223011' -> '000012310300223011' : single(A2, 1)
'000012310300223011' -> '000012301300223011' : single(C3, 1)
'000012301300223011' -> '000012031300223011' : single(A2, 1)
'000012031300223011' -> '000010231300223011' : chord({E3, G4, A5}, 1)
'000010231300223011' -> '000001231300223011' : single(C3, 1)
'000001231300223011' -> '000001231030223011' : single(A2, 1)
'000001231030223011' -> '000001230130223011' : single(C3, 1)
'000001230130223011' -> '000001203130223011' : single(A2, 1)
'000001203130223011' -> '000001023130223011' : chord({E3, G4, A5}, 1)
'000001023130223011' -> '000000123130223011' : single(C3, 1)
'000000123130223011' -> '000000123103223011' : single(A2, 1)
'000000123103223011' -> '000000123013223011' : single(C3, 1)
'000000123013223011' -> '000000120313223011' : single(A2, 1)
'000000120313223011' -> '000000102313223011' : chord({E3, G4, A5}, 1)
'000000102313223011' -> '000000012313223011' : single(C3, 1)
'000000012313223011' -> '000000012313220311' : single(A2, 1)
'000000012313220311' -> '000000012313202311' : chord({E3, G4, A5}, 1)
'000000012313202311' -> '000000012313022311' : chord({E3, G4, A5}, 1)
'000000012313022311' -> '000000012310322311' : single(A2, 1)
'000000012310322311' -> '000000012301322311' : single(C3, 1)
'000000012301322311' -> '000000012031322311' : single(A2, 1)
'000000012031322311' -> '000000010231322311' : chord({E3, G4, A5}, 1)
'000000010231322311' -> '000000001231322311' : single(C3, 1)
'000000001231322311' -> '000000001213322311' : single(G1, 1)
'000000001213322311' -> '000000001123322311' : chord({G3, E4}, 1)
'000000001123322311' -> '000000001123322131' : single(G1, 1)
'000000001123322131' -> '000000001123321231' : chord({G3, E4}, 1)
'000000001123321231' -> '000000001123312231' : chord({G3, E4}, 1)
'000000001123312231' -> '000000001123132231' : single(G1, 1)
'000000001123132231' -> '000000001121332231' : single(G1, 1)
'000000001121332231' -> '000000001112332231' : chord({G3, E4}, 1)
'000000001112332231' -> '000000001112332213' : single(G1, 1)
'000000001112332213' -> '000000001112332123' : chord({G3, E4}, 1)
'000000001112332123' -> '000000001112331223' : chord({G3, E4}, 1)
'000000001112331223' -> '000000001112313223' : single(G1, 1)
'000000001112313223' -> '000000001112133223' : single(G1, 1)
'000000001112133223' -> '000000001111233223' : chord({G3, E4}, 1)
'000000001111233223' -> '000000001111232323' : single(B2, 1)
'000000001111232323' -> '000000001111223323' : single(B2, 1)
'000000001111223323' -> '000000001111223233' : single(B2, 1)
'000000001111223233' -> '000000001111222333' : single(B2, 1)
Execution took 3.660ms
```

I took the output and ran it through some processing:

https://user-images.githubusercontent.com/12176994/172078777-b463f310-24f1-48e2-8890-7364ddef025a.mp4

The first part should be completely unedited, but in the second one I shifted a few notes around just for fun :)

