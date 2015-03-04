/* Changes:  */

/* 1. Character constants removed */
/* 2. Changed INTCONSTANT to INT_CONSTANT */
/* 3. Changed the production for constant_expression to include FLOAT_CONSTANT */
/* 4. Added examples of FLOAT_CONSTANTS */
/* 5. Added the description of STRING_LITERAL */
/* 6. Changed primary_expression and FOR */
/* 7. The grammar permits a empty statement. This should be  */
/*    explicitly represented in the AST. */
/* 8. To avoid local decl inside blocks, a rule for statement  */
/*    has been changed. */

/* ----------------------------------------------------------------------- */

/* start symbol is translation_unit */

/* ---------------------------------------------------- */
%scanner Scanner.h
%scanner-token-function d_scanner.lex()

%token FP_CONST INT_CONST VOID INT FLOAT FOR WHILE IF ELSE RETURN IDENTIFIER
%token LEQ_OP GEQ_OP INCREMENT STRING_LITERAL
%token LOGICAL_AND LOGICAL_OR EQUAL_TO NEQ_TO
%polymorphic expAstPtr: ExpAst*; stmtAstPtr: StmtAst*; arrayRefPtr: ArrayRef*; opType: typeOp; idAttr: std::string;  

%type <stmtAstPtr> assignment_statement statement statement_list selection_statement iteration_statement
%type <expAstPtr> expression logical_and_expression equality_expression relational_expression additive_expression multiplicative_expression unary_expression postfix_expression primary_expression expression_list
%type <arrayRefPtr> l_expression 
%type <opType> unary_operator
%type <idAttr> IDENTIFIER STRING_LITERAL INT_CONST FP_CONST

%%

translation_unit
	: function_definition 
	| translation_unit function_definition 
    ;

function_definition
	: type_specifier 
	{
		_g_offset = 0;
		_g_funcTable.reset();
		_g_funcTable.setReturnType(_g_typeSpec);
	}
	fun_declarator compound_statement 
	{
		_g_globalSymTable.addFuncTable(_g_funcTable);
	}
	;

type_specifier
	: VOID 	
	{
		_g_typeSpec = DECL_P_VOID;
		_g_width = 0;
	}
    | INT   
	{
		_g_typeSpec = DECL_P_INT;
		_g_width = 4;
	}
	| FLOAT 
	{
		_g_typeSpec = DECL_P_FLOAT;
		_g_width = 4;
	}
    ;

fun_declarator
	: IDENTIFIER '(' parameter_list ')'
	{
		// Set the name, check for conflicting args.
		if(	_g_funcTable.existsSymbol($1) )
		{
			cerr << "Duplicate identifier used for function name and arguments" << endl;
			_exit(-1);
		}
		_g_funcTable.setName($1);

	}
    | IDENTIFIER '(' ')'
	{
		_g_funcTable.setName($1);
	}
	;

parameter_list
	: parameter_declaration
	| parameter_list ',' parameter_declaration 
	;

parameter_declaration
	: type_specifier declarator 
	{
		_g_curVarType.setPrimitive(_g_typeSpec);
		VarDeclaration v;
		v.setDeclType(PARAM);
		v.setName(_g_currentId);
		v.setSize(_g_size);
		v.setOffset(_g_offset);
		v.setVarType(_g_varType);
		_g_funcTable.setName($1);
		_g_funcTable.addParam(v);
		_g_offset += _g_size;
	}		
	;

declarator
	: IDENTIFIER 
	{
		_g_currentId = $1;
		_g_varType = new VarType();
		_g_curVarType = _g_varType;
		_g_size = _g_width;
	}
	| declarator '[' INT_CONST ']'  // Changed constant expr to INT_CONST
	{
		_g_curVarType.setArray($3);
		_g_curVarType.setNestedVarType(new VarType());
		_g_curVarType = _g_curVarType.getNestedVarType();
		_g_size *= ($3);
	}
        ;

constant_expression 
        : INT_CONST
        | FP_CONST 
        ;

compound_statement
	: '{' '}' 
	| '{' statement_list '}'
	{
		($2)->print();
		std::cout <<'\n'; 
	} 
	| '{' declaration_list statement_list '}'
	{
		($3)->print();
		std::cout << '\n';
	} 
	;

statement_list
	: statement
	{
		($$) = new Block($1);
	}
    | statement_list statement	
    {
		((Block*)($1))->insert($2);
		($$) = ($1);
	}
	;

statement
        : '{' statement_list '}'
        {
			($$) = ($2);
        }  //a solution to the local decl problem
        | selection_statement 	
        {
			($$) = ($1);
        }
        | iteration_statement
        {
			($$) = ($1);
        } 	
		| assignment_statement	
		{
			($$) = ($1);
		}
        | RETURN expression ';'	
        {
			($$) = new Return( ($2) );
        }
        ;

assignment_statement
	: ';'
	{
		$$ = new Empty();
	} 								
	|  l_expression '=' expression ';'	
	{
		$$ = new Ass($1, $3);
	}
	;

expression
	: logical_and_expression
	{
		$$ = $1;
	} 
	| expression LOGICAL_OR logical_and_expression
	{
		$$ = new BinaryOp($1, $3, OR);
	}
	;

logical_and_expression
	: equality_expression
	{
		$$ = $1;
	}
	| logical_and_expression LOGICAL_AND equality_expression
	{
		$$ = new BinaryOp($1, $3, AND);
	} 
	;

equality_expression
	: relational_expression
	{
		$$ = $1;
	} 
	| equality_expression EQUAL_TO relational_expression
    {
		$$ = new BinaryOp($1, $3, EQ_OP);
	} 	
	| equality_expression NEQ_TO relational_expression
	{
		$$ = new BinaryOp($1, $3, NE_OP);
	}
	;
relational_expression
	: additive_expression
	{
		$$ = $1;
	}
    | relational_expression '<' additive_expression
    {
		$$ = new BinaryOp($1, $3, LT);
	}  
	| relational_expression '>' additive_expression
	{
		$$ = new BinaryOp($1, $3, GT);
	}  
	| relational_expression LEQ_OP additive_expression
	{
		$$ = new BinaryOp($1, $3, LE_OP);
	}  
    | relational_expression GEQ_OP additive_expression 
    {
		$$ = new BinaryOp($1, $3, GE_OP);
	} 
	;

additive_expression 
	: multiplicative_expression
	{
		$$ = $1;
	}
	| additive_expression '+' multiplicative_expression
	{
		$$ = new BinaryOp($1, $3, PLUS);
	} 
	| additive_expression '-' multiplicative_expression
	{
		$$ = new BinaryOp($1, $3, MINUS);
	} 
	;

multiplicative_expression
	: unary_expression
	{
		$$ = $1;
	}
	| multiplicative_expression '*' unary_expression
	{
		$$ = new BinaryOp($1, $3, MULT);
	} 
	| multiplicative_expression '/' unary_expression
	{
		$$ = new BinaryOp($1, $3, DIV);
	} 
	;
unary_expression
	: postfix_expression
	{
		$$ = $1;
	}  				
	| unary_operator postfix_expression
	{	
		$$ = new UnaryOp($2,$1);
	} 
	;

postfix_expression
	: primary_expression
	{
		$$ = $1;
	}
    | IDENTIFIER '(' ')'
    {
		$$ = new FunCall(nullptr);
		((FunCall*)($$))->setName($1);
	}
	| IDENTIFIER '(' expression_list ')' 
	{
		$$ = $3;
		((FunCall*)($3))->setName($1);
	}
	| l_expression INCREMENT
	{
		$$ = new UnaryOp($1, PP);
	}
	;

primary_expression
	: l_expression
	{
		$$ = $1;
	}
    | l_expression '=' expression // added this production
    {
		$$ = new BinaryOp($1, $3, ASSIGN);
	}
	| INT_CONST
	{
		$$ = new IntConst(std::stoi($1));
	}
	| FP_CONST
	{
		$$ = new FloatConst(std::stof($1));
	}
    | STRING_LITERAL
    {
		$$ = new StringConst((std::string)$1);
    }
	| '(' expression ')' 
	{
		$$ = $2;
	}	
	;

l_expression
        : IDENTIFIER
        {
			$$ = new Identifier($1);
		}
        | l_expression '[' expression ']' 	
        {
			$$ = new Index($1, $3);
        }
        ;
expression_list
        : expression
        {
			$$ = new FunCall($1);
        }
        | expression_list ',' expression
        {
			((FunCall*)($1))->insert($3);
			$$ = $1;
        }
        ;
unary_operator
    : '-'
    {
		$$ = UMINUS;
	}
	| '!' 	
	{
		$$ = NOT;
	}
	;

selection_statement
        : IF '(' expression ')' statement ELSE statement 
		{
			($$) = new If( ($3), ($5), ($7));
		}
	;

iteration_statement
	: WHILE '(' expression ')' statement 
	{
		($$) = new While( ($3), ($5));
	}
    | FOR '(' expression ';' expression ';' expression ')' statement  //modified this production
	{
		($$) = new For( ($3), ($5), ($7), ($9));
	}
    ;

declaration_list
        : declaration  					
        | declaration_list declaration
	;

declaration
	: type_specifier declarator_list';'
	;

declarator_list
	: declarator
	| declarator_list ',' declarator 
	;


/* A description of integer and float constants. Not part of the grammar.   */

/* Numeric constants are defined as:  */

/* C-constant: */
/*   C-integer-constant */
/*   floating-point-constant */
 
/* C-integer-constant: */
/*   [1-9][0-9]* */
/*   0[bB][01]* */
/*   0[0-7]* */
/*   0[xX][0-9a-fA-F]* */
 
/* floating-point-constant: */
/*   integer-part.[fractional-part ][exponent-part ] */

/* integer-part: */
/*   [0-9]* */
 
/* fractional-part: */
/*   [0-9]* */
 
/* exponent-part: */
/*   [eE][+-][0-9]* */
/*   [eE][0-9]* */

/* The rule given above is not entirely accurate. Correct it on the basis of the following examples: */

/* 1. */
/* 23.1 */
/* 01.456 */
/* 12.e45 */
/* 12.45e12 */
/* 12.45e-12 */
/* 12.45e+12 */

/* The following are not examples of FLOAT_CONSTANTs: */

/* 234 */
/* . */

/* We have not yet defined STRING_LITERALs. For our purpose, these are */
/* sequence of characters enclosed within a pair of ". If the enclosed */
/* sequence contains \ and ", they must be preceded with a \. Apart from */
/* \and ", the only other character that can follow a \ within a string */
/* are t and n.  */



