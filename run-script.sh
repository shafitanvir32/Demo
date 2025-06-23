g++ -std=c++17 -w -I/usr/include/antlr4-runtime -c C8086Lexer.cpp C8086Parser.cpp Ctester.cpp
g++ -std=c++17 -w C8086Lexer.o C8086Parser.o Ctester.o -L/usr/lib/x86_64-linux-gnu/ -lantlr4-runtime -o Ctester.out -pthread
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu ./Ctester.out $1
