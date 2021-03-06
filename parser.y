%{
    #include <math.h>
    #include <stdio.h>
    #include <ctype.h>
    #include <stdlib.h>
    #include <string.h>

    extern int yylineno;

    char* strConcat(char*, char*);
    char* expression(char*, char*, char);
    char* returnValue(char*);
    void movToEdx(char*);
    void assignValue(char*, char*);
    void printNumber(char*, char);
    void printNewline();
    void printString(char*);
    void startCompare(char*, char*);
    void endCompare();
    int startLoop(char*, char*);
    void endLoop(int);
    void breakLoop();
    void continueLoop();
    void initReg();
    int varToInt(char*);
    int yylex (void);
    void yyerror (char const *);
    int compareNum = 0;
    char reg[26][20];
    char tempInt[20];
    char *codemain = "";
    char *codedata = "";
    int tempVar_ptr = 116;
    int expCount = 0;    
    int compareCount = 0;
    int loopCount = 0;
    int addressLoop = 130;
    int countLC = 2;
    int loopNumber = -1;
  //Function, variable predefine and include headerfile
%}
/* Bison declarations.  */
%locations
%union {
    char * strval;
    int    intval;
}
%type <strval> STR
%type <intval> NUM beforeLoop VAR
%type <strval> value exp 

%token NUM STR PRINT COMPARE LOOP END_OF_FILE
%token NEWLINE VAR BREAK CONTINUE

%left '='
%left '+' '-'
%left '*' '/' '%'
%precedence NEG   /* negation--unary minus */
%% /* The grammar follows.  */

file: input END_OF_FILE     {return;}
    ;

input: line input
    | error input                { yyerrok; }
    | %empty
    ;

line: '\n'
    | exp ';'
    | assign ';'                
    | print ';'   
    | cond 
    | loop 
    | CONTINUE ';'              { if(loopNumber == -1){ yyerror("cannot use continue outside loop"); YYERROR; } else { continueLoop(); } }
    | BREAK ';'                 { if(loopNumber == -1){ yyerror("cannot use break outside loop"); YYERROR; } else { breakLoop(); } } 
    | assign                    { yyerror("missing \";\" at statement"); YYERROR; }
    | print                     { yyerror("missing \";\" at print"); YYERROR; }
    ;

exp: value                      { if(!expCount){ expCount = 1; movToEdx($1);} $$ = $1; }
    | exp '+' exp               { expCount = 2; $$ = expression($1, $3, '+'); }
    | exp '-' exp               { expCount = 2; $$ = expression($1, $3, '-'); }
    | exp '*' exp               { expCount = 2; $$ = expression($1, $3, '*'); }
    | exp '/' exp               { expCount = 2; $$ = expression($1, $3, '/'); }
    | exp '%' exp               { expCount = 2; $$ = expression($1, $3, '%'); }
    | '-' exp  %prec NEG        { expCount = 0; $$ = expression($2, "", 'm'); }
    | '(' exp ')'	            { expCount = 2; $$ = ""; $$ = strConcat($$, $2); }  
    ;

assign: VAR '=' exp             {  assignValue(reg[$1], $3); if(expCount) expCount = 0; tempVar_ptr = 116;}
    ;

print: PRINT '(' printValue ')'
    | PRINT '(' PRINT '(' printValue ')' printValue ')'        { yyerror("cannot have nested print"); YYERROR;  }
    | PRINT '(' PRINT ')'                           { yyerror("cannot have nested print"); YYERROR;  }
    ;

printValue: printValue '+' printValue
    | NUM                       { sprintf(tempInt, "%d", $1); printNumber(tempInt, 'n');}
    | VAR                       { printNumber(reg[$1], 'v'); }
    | NEWLINE                   { printNewline(); }
    | STR                       { printString($1); }
    | assign                    { yyerror("cannot have statement in print"); YYERROR;  }
    | %empty
    ;

cond: beforeCond input '}'       { endCompare(); }
    ;

beforeCond: COMPARE '(' exp ',' exp ')' '{'         { startCompare($3, $5);}
    | COMPARE '('  ',' exp ')' '{'                    { yyerror("incomplete argument"); YYERROR;  }
    | COMPARE '(' exp ','  ')' '{'                    { yyerror("incomplete argument"); YYERROR;  }
    | COMPARE '(' assign ',' exp ')' '{'                    { yyerror("cannot assign in compare"); YYERROR;  }
    | COMPARE '(' exp ',' assign ')' '{'                    { yyerror("cannot assign in compare"); YYERROR;  }
    | COMPARE '(' assign ',' assign ')' '{'                 { yyerror("cannot assign in compare"); YYERROR;  }
    ;

loop: beforeLoop input '}'       { loopNumber--; endLoop($1); }
    ;

beforeLoop: LOOP '(' value ',' value ')' '{'            {loopNumber++; $$ = startLoop($3, $5); }
    ;

value: NUM                  { sprintf(tempInt, "%d", $1); $$ = ""; $$ = strConcat($$,tempInt);}
    | VAR                   { $$ = reg[$1]; }
    ;
%%
// strConcat
// use for extend and concatenate string by reallocate space 
// return pointer to character of new string
char* strConcat(char* first,char* second){
    char* tmp = malloc(strlen(first)+strlen(second)+1);
    strcpy(tmp, first );
    strcat(tmp, second);
    return tmp;
}

// initReg
// use for initialize reg array for store address offset used in assembly file
void initReg(){
    char tmp[20];
    for(int i = 0; i < 26; i++){
        sprintf(tmp,"v%d",((i+1)*4)+4);
        strcpy(reg[i],tmp);
    }
}

// varToInt
// use to convert string begin with v (address) to integer value and 
// other string to 0
// return integer
int varToInt(char *input){
    if(*input == 'v'){
        return(atoi(input+1));
    }
    else
        return(0);
}

// returnValue
// use for change string to value that can really use in assembly
// e.g. v104 (address offset) -> 104(%esp) (esp + 104)
// e.g. 5 (constant integer) -> $5 (constant in AT&T syntax assembly)
// e.g. %edx return input
// return pointer to character of new string
char* returnValue(char* input){
    if(*input == 'v'){
        input = input + 1;
        input = strConcat(input,"(%esp)");
		return input;
    }
    else if(*input == '%'){
        return input;
    }
    else{
        char *str = "$";
        str = strConcat(str, input);
        return str;
    }
}

// movToEdx
// use for write {mov input to edx register} assembly command
void movToEdx(char *input){
    input = returnValue(input);
    char *codetemp = "\tmovl ";
    codetemp = strConcat(codetemp, input);
    codetemp = strConcat(codetemp, ", %edx");
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
}

// printNumber
// use for write assembly instruction set for print integer (input) on screen
void printNumber(char *input, char type){
    char *codetemp = "\tmovl ";

    if(type == 'n'){
        codetemp = strConcat(codetemp, "$");
        codetemp = strConcat(codetemp, input);
    }
    else{
        input = returnValue(input);
        codetemp = strConcat(codetemp, input);
    }
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "subl $4, %esp\n\t");
    codetemp = strConcat(codetemp, "movl %eax, 4(%esp)\n\t");
    codetemp = strConcat(codetemp, "movl $.LC1, (%esp)\n\t");
    codetemp = strConcat(codetemp, "call printf\n\t");
    codetemp = strConcat(codetemp, "addl $4, %esp\n");
    
    codemain = strConcat(codemain, codetemp);
}
// printNewLine
// use for write assembly instruction set for print newline (\n) on screen
void printNewline(){
   
    char *codetemp = "\tmovl $.LC0, (%esp)\n\tcall printf";
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
}

// printString
// use for write assembly instruction set for print string (input) on screen
void printString(char *str){

    //data
    char *datatemp = "\n.LC";
    char str_countLC[100];
    sprintf(str_countLC, "%d", countLC);
    datatemp = strConcat(datatemp, str_countLC);
    datatemp = strConcat(datatemp, ":\n\t.string ");
    datatemp = strConcat(datatemp, str);
    datatemp = strConcat(datatemp, "\0");
    
    codedata = strConcat(codedata, datatemp);

    //main
    char *codetemp = "\tmovl $.LC";
    codetemp = strConcat(codetemp, str_countLC);
    codetemp = strConcat(codetemp, ", (%esp)\n\tcall printf");

    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");

    countLC++;


}

// assignValue
// use for write assembly instruction set for assign value ("=") 
// to selected address (offset(%esp))
void assignValue(char *var, char *temp_var){
    var = returnValue(var);
    temp_var = returnValue(temp_var);
    char *codetemp = "";
    if(expCount == 1 || *temp_var == '%'){
        codetemp = strConcat(codetemp, "\tmovl %edx, ");
    }
    else{
        codetemp = strConcat(codetemp, "\tmovl ");
        codetemp = strConcat(codetemp, temp_var);
        codetemp = strConcat(codetemp, ", %eax\n\t");
        codetemp = strConcat(codetemp, "movl %eax, ");
    }
    codetemp = strConcat(codetemp, var);
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n\n");
}

// expression
// use for write assembly instruction set to perform 
// selected expression (+, -, *, /, %) to input (variable or constant)
// if more than one expression is detected in the same 
// output will be stored in temporary variable (offset 116, 120, 124(%esp))
// return pointer to character of current temporary varible
char* expression(char* first, char* second, char op){
    int tempFirst = varToInt(first);
    int tempSecond = varToInt(second);

    first = returnValue(first);
    second = returnValue(second);
    char *codetemp = "\tmovl ";

    codetemp = strConcat(codetemp, first);
    codetemp = strConcat(codetemp, ", %eax\n");
    if(op == 'm'){
        codetemp = strConcat(codetemp, "\tneg  %eax\n\tmovl  %eax, %edx\n");
        codemain = strConcat(codemain, codetemp);
        return "%edx";
    }
    else{
        codetemp = strConcat(codetemp, "\tmovl ");
        codetemp = strConcat(codetemp, second);
        codetemp = strConcat(codetemp, ", %edx\n\t");
        switch(op){             //output store in %edx

            case '+':
                codetemp = strConcat(codetemp, "addl %eax, %edx\n\t");
                break;
            case '-':
                codetemp = strConcat(codetemp, "subl %edx, %eax\n\tmovl %eax, %edx\n\t");

                break;
            case '*':
                codetemp = strConcat(codetemp, "imull %eax, %edx\n\t");

                break;
            case '/':
                codetemp = strConcat(codetemp, "movl ");
                codetemp = strConcat(codetemp, first);
                codetemp = strConcat(codetemp, ", %eax\n\t");
                codetemp = strConcat(codetemp, "movl %edx, 112(%esp)\n\t");
                codetemp = strConcat(codetemp, "cltd\n\t");
                codetemp = strConcat(codetemp, "idivl 112(%esp)\n\t");
                codetemp = strConcat(codetemp, "movl %eax, %edx\n\t");

                break;
            case '%':
                codetemp = strConcat(codetemp, "movl ");
                codetemp = strConcat(codetemp, first);
                codetemp = strConcat(codetemp, ", %eax\n\t");
                codetemp = strConcat(codetemp, "movl %edx, 112(%esp)\n\t");
                codetemp = strConcat(codetemp, "cltd\n\t");
                codetemp = strConcat(codetemp, "idivl 112(%esp)\n\t");
                //codetemp = strConcat(codetemp, "movl %eax, %edx\n\t");

                break;
        }

        if(tempVar_ptr == 116){     //store %edx value to stack (use as variable)
            codetemp = strConcat(codetemp, "movl %edx, 116(%esp)\n\t"); 
        }
        else if(tempFirst == 0 && tempSecond == 0){
            codetemp = strConcat(codetemp, "movl %edx, 120(%esp)\n\t"); 
        }
        else if(tempFirst == 116 && tempSecond == 0){
            codetemp = strConcat(codetemp, "movl %edx, 116(%esp)\n\t"); 
        }
        else if(tempFirst == 0 && tempSecond == 116){
            codetemp = strConcat(codetemp, "movl %edx, 116(%esp)\n\t"); 
        }
        else if(tempFirst == 120 && tempSecond == 0){
            codetemp = strConcat(codetemp, "movl %edx, 120(%esp)\n\t"); 
        }
        else if(tempFirst == 0 && tempSecond == 120){
            codetemp = strConcat(codetemp, "movl %edx, 120(%esp)\n\t"); 
        }
        else if(tempFirst == 116 && tempSecond == 120){
            codetemp = strConcat(codetemp, "movl %edx, 116(%esp)\n\t"); 
        }
        else if(tempFirst == 120 && tempSecond == 124){
            codetemp = strConcat(codetemp, "movl %edx, 120(%esp)\n\t"); 
        }
        else if(tempFirst == 124 && tempSecond == 0){
            codetemp = strConcat(codetemp, "movl %edx, 124(%esp)\n\t"); 
        }
        else if(tempFirst == 0 && tempSecond == 124){
            codetemp = strConcat(codetemp, "movl %edx, 124(%esp)\n\t"); 
        }
        else{
            codetemp = strConcat(codetemp, "movl %edx, 116(%esp)\n\t");
        }

        codemain = strConcat(codemain, codetemp);
        codemain = strConcat(codemain, "\n");

        if(tempVar_ptr == 116){
			tempVar_ptr = 120;
			return "v116";
		}
        else if(tempFirst == 0 && tempSecond == 0){
			return "v120";
		}
        else if(tempFirst == 0 && tempSecond == 116 ){
			return "v116";
		}
        else if(tempFirst == 116 && tempSecond == 0){
			return "v116";
		}
        else if(tempFirst == 116 && tempSecond == 120){			
			return "v116";
		}
        else if(tempFirst == 0 && tempSecond == 120){
			return "v120";
		}
        else if(tempFirst == 120 && tempSecond == 0 ){
			return "v120";
		}
        else if(tempFirst == 120 && tempSecond == 124){
			return "v120";
		}
        else if(tempFirst == 0 && tempSecond == 124){
			return "v124";
		}
        else if(tempFirst == 124 && tempSecond == 0 ){
			return "v124";
        }
        else{
            return "v116";
        }
        

    }
}

// stratCompare
// use for write assembly instruction set for head of compare block {}
// comment: similiar but simplier for if in C instruction 
void startCompare(char *first, char *second){
    first = returnValue(first);
    second = returnValue(second);

    char strCompareNum[20];
    sprintf(strCompareNum,"%d",compareNum);
    char *codetemp = "\tmovl ";
    codetemp = strConcat(codetemp, first);
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "movl ");
    codetemp = strConcat(codetemp, second);
    codetemp = strConcat(codetemp, ", %edx\n\t");
    codetemp = strConcat(codetemp, "cmpl %eax, %edx\n\t");
    codetemp = strConcat(codetemp, "jne C_Lebel");
    codetemp = strConcat(codetemp, strCompareNum);
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
    
}

// endCompare
// use for write assembly instruction set for end of compare block {}
void endCompare(){
    char strCompareNum[20];
    sprintf(strCompareNum,"%d",compareNum);
    char *codetemp = "";
    codetemp = strConcat(codetemp, "C_Lebel");
    codetemp = strConcat(codetemp, strCompareNum);
    codetemp = strConcat(codetemp, ":\n");
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
    
    compareNum++;
}

// stratLoop
// use for write assembly instruction set for head of loop block {}
// comment: similiar but simplier for for loop in C instruction 
int startLoop(char *first, char *second){
    first = returnValue(first);
    second = returnValue(second);

    char addFirst[20];
    char addSecond[20];
    char strLoopCount[20];

    sprintf(addFirst, "v%d", addressLoop);
    sprintf(addSecond, "v%d", addressLoop+4);
    sprintf(strLoopCount, "%d", loopCount);
    strcpy(addFirst, returnValue(addFirst));
    strcpy(addSecond, returnValue(addSecond));

    char *codetemp = "";
    codetemp = strConcat(codetemp, "\tmovl ");
    codetemp = strConcat(codetemp, first);
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "movl %eax, ");
    codetemp = strConcat(codetemp, addFirst);
    codetemp = strConcat(codetemp, "\n\tmovl ");
    codetemp = strConcat(codetemp, second);
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "movl %eax, ");
    codetemp = strConcat(codetemp, addSecond);

    codetemp = strConcat(codetemp, "\n\tjmp exLoop");
    codetemp = strConcat(codetemp, strLoopCount);
    codetemp = strConcat(codetemp, "\nloop");
    codetemp = strConcat(codetemp, strLoopCount);
    codetemp = strConcat(codetemp, ":");
    
    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");

    addressLoop = addressLoop + 8;
    
    loopCount++;
    return loopCount - 1;
}

// endLoop
// use for write assembly instruction set for end of loop block {}
// e.g. compare condition and jump back to head and something like that 
void endLoop(int loop){
    addressLoop = addressLoop - 8;
    char addFirst[20];
    char addSecond[20];
    char strLoopCount[20];

    sprintf(addFirst, "v%d", addressLoop);
    sprintf(addSecond, "v%d", addressLoop+4);
    sprintf(strLoopCount, "%d", loop);
    strcpy(addFirst, returnValue(addFirst));
    strcpy(addSecond, returnValue(addSecond));

    char *codetemp = "";
    codetemp = strConcat(codetemp, "\tmovl ");
    codetemp = strConcat(codetemp, addFirst);
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "add $1, %eax\n\t");
    codetemp = strConcat(codetemp, "movl %eax, ");
    codetemp = strConcat(codetemp, addFirst);

    codetemp = strConcat(codetemp, "\nexLoop");
    codetemp = strConcat(codetemp, strLoopCount);
    codetemp = strConcat(codetemp, ":\n\t");

    codetemp = strConcat(codetemp, "movl ");
    codetemp = strConcat(codetemp, addFirst);
    codetemp = strConcat(codetemp, ", %eax\n\t");
    codetemp = strConcat(codetemp, "movl ");
    codetemp = strConcat(codetemp, addSecond);
    codetemp = strConcat(codetemp, ", %edx\n\t");
    codetemp = strConcat(codetemp, "cmpl %edx, %eax\n\t");
    codetemp = strConcat(codetemp, "jle loop");
    codetemp = strConcat(codetemp, strLoopCount);

    codetemp = strConcat(codetemp, "\nextLoop");
    codetemp = strConcat(codetemp, strLoopCount);
    codetemp = strConcat(codetemp, ":\n");

    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
}

// breakLoop
// use for write assembly instruction set break out of loop block {}
void breakLoop(){

    char strLoopCount[20];
    sprintf(strLoopCount, "%d", loopNumber);
    char *codetemp = "";
    codetemp = strConcat(codetemp, "\tjmp extLoop");
    codetemp = strConcat(codetemp, strLoopCount);

    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");

}

// continueLoop
// use for write assembly instruction set continue on loop block {}
// skip instruction under "continue" and begin new loop
void continueLoop(){
    char strLoopCount[20];
    sprintf(strLoopCount, "%d", loopNumber);

    char *codetemp = "";
    codetemp = strConcat(codetemp, "\tjmp exLoop");
    codetemp = strConcat(codetemp, strLoopCount);

    codemain = strConcat(codemain, codetemp);
    codemain = strConcat(codemain, "\n");
}

void yyerror (char const *s)              // error message
{
  fprintf (stderr, "Error: %s At line %d\n", s, yylineno);
}

int main(void){
    initReg();
    yyparse();                        // strat parser
    char *codetemp = "";
    // head of assembly file before main function
    codetemp = strConcat(codetemp, "\n\t.section    .rodata\n");
    codetemp = strConcat(codetemp, ".LC0:\n\t");
    codetemp = strConcat(codetemp, ".string \"\\n\\0\"\n");
    codetemp = strConcat(codetemp, ".LC1:\n\t");
    codetemp = strConcat(codetemp, ".string \"%d\\0\"\n\t");

    codetemp = strConcat(codetemp, codedata);

    codetemp = strConcat(codetemp, "\n\t.text\n\t.globl main\n\t.type main, @function\n");
    codetemp = strConcat(codetemp, "main:\n.LFB0:\n\t");
    codetemp = strConcat(codetemp, ".cfi_startproc\n\tpushl	%ebp\n\t.cfi_def_cfa_offset 8\n\t");
    codetemp = strConcat(codetemp, ".cfi_offset 5, -8\n\tmovl	%esp, %ebp\n\t.cfi_def_cfa_register 5\n\t");

    codetemp = strConcat(codetemp, codemain);

    // end of assembly file after main function
    codetemp = strConcat(codetemp, "\tleave\n\t.cfi_restore 5\n\t.cfi_def_cfa 4, 4\n\tret\n\t.cfi_endproc\n");
    codetemp = strConcat(codetemp, ".LFE0:\n\t.size	main, .-main\n\t");
    codetemp = strConcat(codetemp, ".ident	\"GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.9) 5.4.0 20160609\"\n\t");
    codetemp = strConcat(codetemp, ".section	.note.GNU-stack,\"\",@progbits");



    FILE *fp;
    fp = fopen("output.s","w+");
    fprintf(fp, "%s", codetemp);
    fclose(fp);
   
    return 0; 
}