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
    extern SymbolTable* symtab;
}

@parser::members {
    /****************** generic helpers ******************/
    void writeIntoparserLogFile(const std::string& message) {
        if (!parserLogFile) {
            std::cout << "Error opening parserLogFile.txt" << std::endl;
            return;
        }
        parserLogFile << message << std::endl;
        parserLogFile.flush();
    }

    void writeIntoErrorFile(const std::string& message) {
        if (!errorFile) {
            std::cout << "Error opening errorFile.txt" << std::endl;
            return;
        }
        errorFile << message << std::endl;
        errorFile.flush();
    }

    // ---------------- universal rule‑logger ----------------
    /**
     * Emit a line identical to the reference log.
     *   Line <line#>: <ruleName> : <rhs>
     *   <exact source lexeme(s) matched by rule>
     */
    void logRule(const std::string& ruleName,
                 const std::string& rhs,
                 antlr4::ParserRuleContext* ctx)
    {
        size_t line = ctx->getStart()->getLine();
        writeIntoparserLogFile(
            "Line " + std::to_string(line) + ": " + ruleName + " : " + rhs + "\n\n" +
            ctx->getText() + "\n");
    }

    /**************** symbol‑table helpers *******************/
    void insertVarList(const str_list& vars,
                       const std::string& type,
                       size_t line)
    {
        for (const std::string& v : vars.get_variables()) {
            bool ok = symtab->insert_into_current_scope(v, type);
            std::string msg = (ok
                 ? "Inserted '" + v + "' of type " + type
                 : "Redeclaration of '" + v + "' ignored");

            writeIntoparserLogFile(
               "Line# " + std::to_string(line) + " – " + msg);
        }
    }

    void printAndPopScope() {
        symtab->print_current_scope_table();
        symtab->exit_scope();
    }
}

/****************************************************************/
/*                        grammar rules                         */
/****************************************************************/

start
    : program               { logRule("start", "program", _ctx); }
      { writeIntoparserLogFile("Parsing completed successfully with " + std::to_string(syntaxErrorCount) + " syntax errors."); }
    ;

program
    : program unit          { logRule("program", "program unit", _ctx); }
    | unit                  { logRule("program", "unit", _ctx); }
    ;

unit
    : var_declaration       { logRule("unit", "var_declaration", _ctx); }
    | func_declaration      { logRule("unit", "func_declaration", _ctx); }
    | func_definition       { logRule("unit", "func_definition", _ctx); }
    ;

/****************************************************************/
/*                    declarations & types                      */
/****************************************************************/

type_specifier returns [std::string name]
    : INT   { $name = "int";   logRule("type_specifier", "INT",   _ctx); }
    | FLOAT { $name = "float"; logRule("type_specifier", "FLOAT", _ctx); }
    | VOID  { $name = "void";  logRule("type_specifier", "VOID",  _ctx); }
    ;

/** declaration list *******************************************/

declaration_list returns [str_list var_list]
    : dl=declaration_list COMMA ID
        {
            $var_list.set_variables($dl.var_list.get_variables());
            $var_list.add($ID->getText());
        }
        { logRule("declaration_list", "declaration_list COMMA ID", _ctx); }
    | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
        { /* array variant – no need to store size for this project */ }
        { logRule("declaration_list", "declaration_list COMMA ID LTHIRD CONST_INT RTHIRD", _ctx); }
    | ID
        {
            $var_list.add($ID->getText());
        }
        { logRule("declaration_list", "ID", _ctx); }
    | ID LTHIRD CONST_INT RTHIRD
        { $var_list.add($ID->getText()); }
        { logRule("declaration_list", "ID LTHIRD CONST_INT RTHIRD", _ctx); }
    ;

var_declaration
    : t=type_specifier dl=declaration_list sm=SEMICOLON
        {
            insertVarList($dl.var_list, $t.name, $sm->getLine());
        }
        { logRule("var_declaration", "type_specifier declaration_list SEMICOLON", _ctx); }
    | t=type_specifier de=declaration_list_err sm=SEMICOLON
        {
            writeIntoErrorFile("Line# " + std::to_string($sm->getLine()) + " with error name: " + $de.error_name + " - Syntax error at declaration list of variable declaration");
            syntaxErrorCount++;
        }
    ;

declaration_list_err returns [std::string error_name]
    : { $error_name = "Error in declaration list"; }
    ;

/****************************************************************/
/*                     functions & parameters                   */
/****************************************************************/

func_declaration
    : ts=type_specifier fn=ID LPAREN parameter_list RPAREN SEMICOLON
        {
            symtab->insert_into_current_scope($fn->getText(), "FUNC");
        }
        { logRule("func_declaration", "type_specifier ID LPAREN parameter_list RPAREN SEMICOLON", _ctx); }
    | ts2=type_specifier fn2=ID LPAREN RPAREN SEMICOLON
        {
            symtab->insert_into_current_scope($fn2->getText(), "FUNC");
        }
        { logRule("func_declaration", "type_specifier ID LPAREN RPAREN SEMICOLON", _ctx); }
    ;

func_definition
    : ts=type_specifier fn=ID LPAREN
        {
            symtab->insert_into_current_scope($fn->getText(), "FUNC");
            symtab->enter_scope(); // param scope
        }
        (pl=parameter_list)? RPAREN cs=compound_statement
        {
            /* cs already popped its own scope; nothing left to do */
        }
        { logRule("func_definition", "type_specifier ID LPAREN parameter_list? RPAREN compound_statement", _ctx); }
    ;

parameter_list returns [str_list params]
    : p1=type_specifier id1=ID
        {
            $params.add($id1->getText());
            insertVarList($params, $p1.name, $id1->getLine());
        }
        { logRule("parameter_list", "type_specifier ID", _ctx); }
        ( COMMA p2=type_specifier id2=ID
            {
                $params.add($id2->getText());
                insertVarList($params, $p2.name, $id2->getLine());
            }
            { logRule("parameter_list", "parameter_list COMMA type_specifier ID", _ctx); }
        )*
    ;

/****************************************************************/
/*                           blocks                             */
/****************************************************************/

compound_statement locals [bool own=false]
    : LCURL
        { symtab->enter_scope(); $own=true; }
        statements? RCURL
        {
            if($own) printAndPopScope();
        }
        { logRule("compound_statement", "LCURL statements RCURL", _ctx); }
    | LCURL RCURL
        { logRule("compound_statement", "LCURL RCURL", _ctx); }
    ;

statements
    : statement               { logRule("statements", "statement", _ctx); }
    | statements statement    { logRule("statements", "statements statement", _ctx); }
    ;

/****************************************************************/
/*                           statements                         */
/****************************************************************/

statement
    : var_declaration                      { logRule("statement", "var_declaration", _ctx); }
    | expression_statement                 { logRule("statement", "expression_statement", _ctx); }
    | compound_statement                   { logRule("statement", "compound_statement", _ctx); }
    | FOR LPAREN expression_statement expression_statement expression RPAREN statement
        { logRule("statement", "FOR LPAREN expression_statement expression_statement expression RPAREN statement", _ctx); }
    | IF LPAREN expression RPAREN statement
        { logRule("statement", "IF LPAREN expression RPAREN statement", _ctx); }
    | IF LPAREN expression RPAREN statement ELSE statement
        { logRule("statement", "IF LPAREN expression RPAREN statement ELSE statement", _ctx); }
    | WHILE LPAREN expression RPAREN statement
        { logRule("statement", "WHILE LPAREN expression RPAREN statement", _ctx); }
    | PRINTLN LPAREN ID RPAREN SEMICOLON
        { logRule("statement", "PRINTLN LPAREN ID RPAREN SEMICOLON", _ctx); }
    | RETURN expression SEMICOLON
        { logRule("statement", "RETURN expression SEMICOLON", _ctx); }
    ;

expression_statement
    : SEMICOLON                    { logRule("expression_statement", "SEMICOLON", _ctx); }
    | expression SEMICOLON         { logRule("expression_statement", "expression SEMICOLON", _ctx); }
    ;

/****************************************************************/
/*                       expressions family                      */
/****************************************************************/

variable
    : ID                               { logRule("variable", "ID", _ctx); }
    | ID LTHIRD expression RTHIRD       { logRule("variable", "ID LTHIRD expression RTHIRD", _ctx); }
    ;

expression
    : logic_expression                           { logRule("expression", "logic expression", _ctx); }
    | variable ASSIGNOP logic_expression         { logRule("expression", "variable ASSIGNOP logic_expression", _ctx); }
    ;

logic_expression
    : rel_expression                               { logRule("logic_expression", "rel_expression", _ctx); }
    | rel_expression LOGICOP rel_expression        { logRule("logic_expression", "rel_expression LOGICOP rel_expression", _ctx); }
    ;

rel_expression
    : simple_expression                            { logRule("rel_expression", "simple_expression", _ctx); }
    | simple_expression RELOP simple_expression     { logRule("rel_expression", "simple_expression RELOP simple_expression", _ctx); }
    ;

simple_expression
    : term                                          { logRule("simple_expression", "term", _ctx); }
    | simple_expression ADDOP term                  { logRule("simple_expression", "simple_expression ADDOP term", _ctx); }
    ;

term
    : unary_expression                              { logRule("term", "unary_expression", _ctx); }
    | term MULOP unary_expression                   { logRule("term", "term MULOP unary_expression", _ctx); }
    ;

unary_expression
    : ADDOP unary_expression                        { logRule("unary_expression", "ADDOP unary_expression", _ctx); }
    | NOT unary_expression                          { logRule("unary_expression", "NOT unary_expression", _ctx); }
    | factor                                        { logRule("unary_expression", "factor", _ctx); }
    ;

factor
    : variable                                      { logRule("factor", "variable", _ctx); }
    | ID LPAREN argument_list RPAREN                { logRule("factor", "ID LPAREN argument_list RPAREN", _ctx); }
    | LPAREN expression RPAREN                      { logRule("factor", "LPAREN expression RPAREN", _ctx); }
    | CONST_INT                                     { logRule("factor", "CONST_INT", _ctx); }
    | CONST_FLOAT                                   { logRule("factor", "CONST_FLOAT", _ctx); }
    | variable INCOP                                { logRule("factor", "variable INCOP", _ctx); }
    | variable DECOP                                { logRule("factor", "variable DECOP", _ctx); }
    ;

/****************************************************************/
/*                    arguments & argument list                  */
/****************************************************************/

argument_list
    : arguments                      { logRule("argument_list", "arguments", _ctx); }
    |                                { logRule("argument_list", "", _ctx); }
    ;

arguments
    : arguments COMMA logic_expression   { logRule("arguments", "arguments COMMA logic_expression", _ctx); }
    | logic_expression                    { logRule("arguments", "logic_expression", _ctx); }
    ;
