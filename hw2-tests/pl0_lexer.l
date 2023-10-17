/* $Id: pl0_lexer_definitions_top.l,v 1.2 2023/10/06 11:12:37 leavens Exp leavens $ */
/* Lexical Analyzer for PL/0 */

%option header-file = "pl0_lexer.h"
%option outfile = "pl0_lexer.c"
%option yylineno
%option bison-bridge

%{
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <limits.h>
#include "ast.h"
#include "parser_types.h"
#include "utilities.h"
#include "lexer.h"

 /* Tokens generated by Bison */
#include "pl0.tab.h"

 /* need declaration of fileno, part of the C standard library.
   (Putting an extern declaration here shuts off a gcc warning.) */
extern int fileno(FILE *stream);

/* The filename of the file being read */
char *filename;

/* Have any errors been noted? */
bool errors_noted;

/* The value of a token */
extern YYSTYPE yylval;

/* The FILE used by the generated lexer */
extern FILE *yyin;

#undef yywrap   /* sometimes a macro by default */

// apparently strdup is not declared in <string.h>
extern char *strdup(const char *s);

// set the lexer's value for a token in yylval as an AST
static void tok2ast(int code) {
    AST t;
    t.token.file_loc = file_location_make(filename, yylineno);
    t.token.type_tag = token_ast;
    t.token.code = code;
    t.token.text = strdup(yytext);
    yylval = t;
}

static void ident2ast(const char *name) {
    AST t;
    t.ident.file_loc = file_location_make(filename, yylineno);
    t.ident.type_tag = ident_ast;
    t.ident.name = strdup(name);
    yylval = t;
}

static void number2ast(unsigned int val)
{
    AST t;
    t.number.file_loc = file_location_make(filename, yylineno);
    t.number.type_tag = number_ast;
    t.number.text = strdup(yytext);
    t.number.value = val;
    yylval = t;
}

%}

/* you can add actual definitions below */

/* the rules section starts after the %% below */
/* Regular expressions for basic token types */
letter           [_a-zA-Z]
digit            [0-9]
letter_or_digit  {letter}|{digit}
ident            {letter}{letter_or_digit}*
number           {digit}+
punctuation      [.;=,()\+\-\*/]
reserved_word    const|var|procedure|call|begin|end|if|then|else|while|do|read|write|skip|odd
rel_ops          <>|<|<=|>|>=
blank            [ ]
tab              [\t]
vt               [\v]
formfeed         [\f]
newline          [\n]
cr               [\r]
eol              {newline}|{cr}{newline}
comment          #[^\n]*{newline}

/* Adjusted Rules section with symbols from the provided enumeration */
%%  /* Rules section */


[ \t\n]+                 {;}   /* Ignore whitespace */
{comment}|{eol}|{cr}|{formfeed}|{vt}               {;}   /* Ignore comments */




"+"                    { tok2ast(plussym); return plussym; }
"-"                    { tok2ast(minussym); return minussym; }
"*"                    { tok2ast(multsym); return multsym; }
"/"                      { tok2ast(divsym); return divsym; }
"."                      { tok2ast(periodsym); return periodsym; }
";"                      { tok2ast(semisym); return semisym; }
"="                      { tok2ast(eqsym); return eqsym; }
","                      { tok2ast(commasym); return commasym; }
":="                     { tok2ast(becomessym); return becomessym; }


"const"                  { tok2ast(constsym);    return constsym; }
"var"                    { tok2ast(varsym);      return varsym; }
"procedure"              { tok2ast(proceduresym);  return proceduresym; }
"call"                   { tok2ast(callsym);  return callsym; }
"begin"                  { tok2ast(beginsym);  return beginsym; }
"end"                    { tok2ast(endsym);  return endsym; }
"if"                     { tok2ast(ifsym);  return ifsym; }
"then"                   { tok2ast(thensym);  return thensym; }
"else"                   { tok2ast(elsesym);  return elsesym; }
"while"                  { tok2ast(whilesym);  return whilesym; }
"do"                     { tok2ast(dosym);  return dosym; }
"read"                   { tok2ast(readsym);  return readsym; }
"write"                  { tok2ast(writesym);  return writesym; }
"skip"                   { tok2ast(skipsym); return skipsym; }
"odd"                    { tok2ast(oddsym); return oddsym; }

{ident}                  { ident2ast(yytext); return identsym; }       /* Identifier token */
{number}                 {
                            long val = atol(yytext); 
                            if (val > INT_MAX) {
                                char msgbuf[512];
                                sprintf(msgbuf, "Number (%s) is too large!\n", yytext);
                                yyerror(lexer_filename(), msgbuf);
                            }
                            number2ast((int)val); 
                            return numbersym; 
                         }

"<>"                 { tok2ast(neqsym); return neqsym; }
"<"                    { tok2ast(ltsym); return ltsym; }
"<="                   { tok2ast(leqsym); return leqsym; }
">"                    { tok2ast(gtsym); return gtsym; }
">="                   { tok2ast(geqsym); return geqsym; }
"("                    { tok2ast(lparensym); return lparensym; }
")"                    { tok2ast(rparensym); return rparensym; }

.   { char msgbuf[512];
      sprintf(msgbuf, "invalid character: '%c' ('\\0%o')", *yytext, *yytext);
      yyerror(lexer_filename(), msgbuf);
    }
%%


 // Requires: fname is the name of a readable file
 // Initialize the lexer and start it reading
 // from the given file name
void lexer_init(char *fname)
{
    errors_noted = false;
    yyin = fopen(fname, "r");
    if (yyin == NULL) {
	bail_with_error("Cannot open %s", fname);
    }
    filename = fname;
}

// Close the file yyin
// and return 0 to indicate that there are no more files
int yywrap() {
    if (yyin != NULL) {
	int rc = fclose(yyin);
	if (rc == EOF) {
	    bail_with_error("Cannot close %s!", filename);
	}
    }
    filename = NULL;
    return 1;  /* no more input */
}

// Return the name of the current input file
const char *lexer_filename() {
    return filename;
}

// Return the line number of the next token
unsigned int lexer_line() {
    return yylineno;
}

/* Report an error to the user on stderr */
void yyerror(const char *filename, const char *msg)
{
    fflush(stdout);
    fprintf(stderr, "%s:%d: %s\n", filename, lexer_line(), msg);
    errors_noted = true;
}

// On standard output:
// Print a message about the file name of the lexer's input
// and then print a heading for the lexer's output.
void lexer_print_output_header()
{
    printf("Tokens from file %s\n", lexer_filename());
    printf("%-6s %-4s  %s\n", "Number", "Line", "Text");
}

// Print information about the token t to stdout
// followed by a newline
void lexer_print_token(enum yytokentype t, unsigned int tline,
		       const char *txt)
{
    printf("%-6d %-4d \"%s\"\n", t, tline, txt);
}


/* Read all the tokens from the input file
 * and print each token on standard output
 * using the format in lexer_print_token */
void lexer_output()
{
    lexer_print_output_header();
    AST dummy;
    yytoken_kind_t t;
    do {
	t = yylex(&dummy);
	if (t == YYEOF) {
	    break;
        }
        lexer_print_token(t, yylineno, yytext);
    } while (t != YYEOF);
}