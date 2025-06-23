parser grammar C8086Parser;

options {
    tokenVocab = C8086Lexer;
}

@parser::header {
    #include <iostream>
    #include <fstream>
    #include <string>
    #include <cstdlib>
    #include "C8086Lexer.h"
    #include "str_list.cpp"
    #include "SymbolTable.hpp"

    extern std::ofstream parserLogFile;
    extern std::ofstream errorFile;

    extern int syntaxErrorCount;
    extern SymbolTable* symbolTable;
}

@parser::members {
    void writeIntoparserLogFile(const std::string message) {
        if (!parserLogFile) {
            std::cout << "Error opening parserLogFile.txt" << std::endl;
            return;
        }

        parserLogFile << message << std::endl;
        parserLogFile.flush();
    }

    void writeIntoErrorFile(const std::string message) {
        if (!errorFile) {
            std::cout << "Error opening errorFile.txt" << std::endl;
            return;
        }
        errorFile << message << std::endl;
        errorFile.flush();
    }

    template<typename CTX>
    void logRule(CTX* ctx, const std::string& ruleDesc) {
        writeIntoparserLogFile(
            "Line " + std::to_string(ctx->getStart()->getLine()) + ": " + ruleDesc);
        writeIntoparserLogFile(ctx->getText());
    }
}


start : program
        {
            logRule(_localctx, "start : program");
            writeIntoparserLogFile("Parsing completed successfully with " + std::to_string(syntaxErrorCount) + " syntax errors.");
        }
        ;

program
    : program unit
        { logRule(_localctx, "program : program unit"); }
    | unit
        { logRule(_localctx, "program : unit"); }
    ;
	
unit
    : var_declaration     { logRule(_localctx, "unit : var_declaration"); }
    | func_declaration    { logRule(_localctx, "unit : func_declaration"); }
    | func_definition     { logRule(_localctx, "unit : func_definition"); }
    ;
     
func_declaration
    : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON
        { logRule(_localctx, "func_declaration : type_specifier ID LPAREN parameter_list RPAREN SEMICOLON"); }
    | type_specifier ID LPAREN RPAREN SEMICOLON
        { logRule(_localctx, "func_declaration : type_specifier ID LPAREN RPAREN SEMICOLON"); }
    ;

func_definition
    : type_specifier ID LPAREN parameter_list RPAREN compound_statement
        { logRule(_localctx, "func_definition : type_specifier ID LPAREN parameter_list RPAREN compound_statement"); }
    | type_specifier ID LPAREN RPAREN compound_statement
        { logRule(_localctx, "func_definition : type_specifier ID LPAREN RPAREN compound_statement"); }
    ;


parameter_list
    : parameter_list COMMA type_specifier ID
        { logRule(_localctx, "parameter_list : parameter_list COMMA type_specifier ID"); }
    | parameter_list COMMA type_specifier
        { logRule(_localctx, "parameter_list : parameter_list COMMA type_specifier"); }
    | type_specifier ID
        { logRule(_localctx, "parameter_list : type_specifier ID"); }
    | type_specifier
        { logRule(_localctx, "parameter_list : type_specifier"); }
    ;

 		
compound_statement
    : LCURL { symbolTable->enter_scope(); } statements RCURL
        {
            symbolTable->print_current_scope_table(parserLogFile);
            symbolTable->exit_scope();
            logRule(_localctx, "compound_statement : LCURL statements RCURL");
        }
    | LCURL { symbolTable->enter_scope(); } RCURL
        {
            symbolTable->print_current_scope_table(parserLogFile);
            symbolTable->exit_scope();
            logRule(_localctx, "compound_statement : LCURL RCURL");
        }
    ;
 		    
var_declaration
    : t=type_specifier dl=declaration_list SEMICOLON {
        for (const auto& v : $dl.var_list.get_variables()) {
            symbolTable->insert_into_current_scope(v, "ID");
        }
        logRule(_localctx, "var_declaration : type_specifier declaration_list SEMICOLON");
      }
    | t=type_specifier de=declaration_list_err SEMICOLON {
        writeIntoErrorFile(
            std::string("Line# ") + std::to_string($SEMICOLON->getLine()) +
            " with error name: " + $de.error_name);
        syntaxErrorCount++;
      }
    ;

declaration_list_err returns [std::string error_name]: {
        $error_name = "Error in declaration list";
    };

 		 
type_specifier returns [std::string name_line]
        : INT {
            $name_line = "type: INT at line" + std::to_string($INT->getLine());
            logRule(_localctx, "type_specifier : INT");
        }
        | FLOAT {
            $name_line = "type: FLOAT at line" + std::to_string($FLOAT->getLine());
            logRule(_localctx, "type_specifier : FLOAT");
        }
        | VOID {
            $name_line = "type: VOID at line" + std::to_string($VOID->getLine());
            logRule(_localctx, "type_specifier : VOID");
        }
        ;
// declaration_list : declaration_list COMMA ID
//                   | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
//                   | ID
// 					 | ID LTHIRD CONST_INT RTHIRD

declaration_list returns [str_list var_list]
    : dl=declaration_list COMMA ID
        {
            $var_list.set_variables($dl.var_list.get_variables());
            $var_list.add($ID->getText());
            logRule(_localctx, "declaration_list : declaration_list COMMA ID");
        }
    | ID
        {
            $var_list.add($ID->getText());
            logRule(_localctx, "declaration_list : ID");
        }
    ;
 		  
statements : statement
	   | statements statement
	   ;
	   
statement : var_declaration
	  | expression_statement
	  | compound_statement
	  | FOR LPAREN expression_statement expression_statement expression RPAREN statement
	  | IF LPAREN expression RPAREN statement
	  | IF LPAREN expression RPAREN statement ELSE statement
	  | WHILE LPAREN expression RPAREN statement
	  | PRINTLN LPAREN ID RPAREN SEMICOLON
	  | RETURN expression SEMICOLON
	  ;
	  
expression_statement 	: SEMICOLON			
			| expression SEMICOLON 
			;
	  
variable : ID 		
	 | ID LTHIRD expression RTHIRD 
	 ;
	 
 expression : logic_expression	
	   | variable ASSIGNOP logic_expression 	
	   ;
			
logic_expression : rel_expression 	
		 | rel_expression LOGICOP rel_expression 	
		 ;
			
rel_expression	: simple_expression 
		| simple_expression RELOP simple_expression	
		;
				
simple_expression : term 
		  | simple_expression ADDOP term 
		  ;
					
term :	unary_expression
     |  term MULOP unary_expression
     ;

unary_expression : ADDOP unary_expression  
		 | NOT unary_expression 
		 | factor 
		 ;
	
factor	: variable 
	| ID LPAREN argument_list RPAREN
	| LPAREN expression RPAREN
	| CONST_INT 
	| CONST_FLOAT
	| variable INCOP 
	| variable DECOP
	;
	
argument_list : arguments
			  |
			  ;
	
arguments : arguments COMMA logic_expression
	      | logic_expression
	      ;
