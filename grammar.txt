program -> definition program2 .
program2 -> program .
program2 -> .

definition -> fun IDENTIFIER op parameters cp definition2 .
definition -> var IDENTIFIER eq initializers .
definition2 -> .
definition2 -> assign statements .

parameters -> IDENTIFIER parameters2 .
parameters -> .
parameters2 -> comma IDENTIFIER parameters2 .
parameters2 -> .

statements -> statement statements2 .
statements2 -> comma statements .
statements2 -> .

statement -> expression statement2 .
statement -> if expression then statements statementIfElse .
statement -> while expression do statements end .
statement -> let statementDef in statements end .
statement2 -> eq expression .
statement2 -> .

statementIfElse -> else statements end .
statementIfElse -> end .

statementDef -> definition statementDef2 .
statementDef2 -> statementDef .
statementDef2 -> .

expression -> orExpression .

orExpression -> andExpression orExpression2 .
orExpression2 -> OR orExpression .
orExpression2 -> .

andExpression -> compExpression andExpression2 .
andExpression2 -> AND andExpression .
andExpression2 -> .

compExpression -> addExpression compExpression2 .
compExpression2 -> EQU addExpression .
compExpression2 -> NEQ addExpression .
compExpression2 -> LTH addExpression .
compExpression2 -> GTH addExpression .
compExpression2 -> LEQ addExpression .
compExpression2 -> GEQ addExpression .
compExpression2 -> .

addExpression -> mulExpression addExpression2 .
addExpression2 -> ADD mulExpression addExpression2 .
addExpression2 -> SUB mulExpression addExpression2 .
addExpression2 -> .

mulExpression -> prefixExpression mulExpression2 .
mulExpression2 -> MUL prefixExpression mulExpression2 .
mulExpression2 -> DIV prefixExpression mulExpression2 .
mulExpression2 -> MOD prefixExpression mulExpression2 .
mulExpression2 -> .

prefixExpression -> postfixExpression .
prefixExpression -> NOT prefixExpression .
prefixExpression -> SUB prefixExpression .
prefixExpression -> ADD prefixExpression .
prefixExpression -> PTR prefixExpression .

postfixExpression -> primaryExpression postfixExpression2 .
postfixExpression2 -> PTR postfixExpression2 .
postfixExpression2 -> .

primaryExpr -> INTCONST .
primaryExpr -> CHARCONST .
primaryExpr -> STRINGCONST .
primaryExpr -> IDENTIFIER primaryExpr2 .
primaryExpr -> OP expression CP .
primaryExpr2 -> OP arguments CP .
primaryExpr2 -> .

arguments -> expression arguments2 .
arguments -> .
arguments2 -> comma expression arguments2 .
arguments2 -> .

initializers -> initializer initializers2 .
initializers -> .
initializers2 -> comma initializer initializers2 .
initializers2 -> .

initializer -> INTCONST initializer2 .
initializer -> CHARCONST .
initializer -> STRINGCONST .
initializer2 -> asterisk initializer3 .
initializer2 -> .

initializer3 -> INTCONST .
initializer3 -> CHARCONST .
initializer3 -> STRINGCONST .
