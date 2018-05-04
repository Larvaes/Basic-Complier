bison:
	bison -d parser.y
	flex lexer.l
	gcc parser.tab.c lex.yy.c -lfl -o complier -lm

asm:
	./complier < input.txt
	gcc -g -m32 output.s -o output
