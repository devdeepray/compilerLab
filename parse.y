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

%token TOK_FP_CONST TOK_INT_CONST TOK_VOID_KW TOK_INT_KW TOK_FLOAT_KW TOK_FOR_KW
%token TOK_WHILE_KW TOK_IF_KW TOK_ELSE_KW TOK_RETURN_KW TOK_IDENTIFIER
%token TOK_LEQ_OP TOK_GEQ_OP TOK_INCR_OP TOK_STR_CONST
%token TOK_LAND_OP TOK_LOR_OP TOK_EQ_OP TOK_NEQ_OP

%polymorphic 
    expAstPtr: ExpAst*;
    stmtAstPtr: StmtAst*; 
    arrayRefPtr: ArrayRef*; 
    opType: typeOp; 
    idAttr: std::string;  

%type <stmtAstPtr> assignment_statement statement 
%type <stmtAstPtr> statement_list selection_statement iteration_statement

%type <expAstPtr> expression logical_and_expression equality_expression
%type <expAstPtr> relational_expression additive_expression
%type <expAstPtr> multiplicative_expression unary_expression 
%type <expAstPtr> postfix_expression primary_expression expression_list

%type <arrayRefPtr> l_expression 
%type <opType> unary_operator
%type <idAttr> TOK_IDENTIFIER TOK_STR_CONST TOK_INT_CONST TOK_FP_CONST

%%

translation_unit
	: function_definition
	{
		// _g_globalSymTable.print();
	} 
	| translation_unit function_definition 
	{
		// _g_globalSymTable.print();
	}
  	;

function_definition
	: type_specifier 
	{
		_g_offset = 0;
		_g_funcTable.reset();
		_g_funcTable.setReturnType(_g_typeSpec);
		_g_functionDefError = false;
		_g_functionStartLno = _g_lineCount;
	}
	fun_declarator  compound_statement 
	{
		if(!_g_functionDefError)
		{
			_g_funcTable.correctOffsets();
			_g_globalSymTable.addFuncTable(_g_funcTable);
		}
		else
		{
		    cat::parse::fdeferror(_g_functionStartLno, _g_funcTable.getName());
		    _g_semanticError = true;
		}
	}
	;

type_specifier
	: TOK_VOID_KW 	
	{
		_g_typeSpec = DECL_P_VOID;
		_g_width = 0;
	}
    | TOK_INT_KW   
	{
		_g_typeSpec = DECL_P_INT;
		_g_width = 4;
	}
	| TOK_FLOAT_KW 
	{
		_g_typeSpec = DECL_P_FLOAT;
		_g_width = 4;
	}
    ;

fun_declarator
	: TOK_IDENTIFIER '(' parameter_list ')'
	{
		// Set the name, check for conflicting args.
		if(	_g_funcTable.existsSymbol($1) )
		{
		    cat::parse::fdeferror(_g_lineCount, "Duplicate identifiers used");
			
			_g_functionDefError = true;
			_g_semanticError = true;
		}
		
		else if( _g_globalSymTable.existsSymbol($1) )
		{
            cat::parse::fdeferror(_g_lineCount, "Duplicate function name");
			_g_functionDefError = true;
			_g_semanticError = true;
		}
		// !!TODO!!
		// If repeated function name with same argument pattern,
		// then it is a duplicate definition. Report error.
		_g_funcTable.setName($1);

	}
    | TOK_IDENTIFIER '(' ')'
	{
		
		if( _g_globalSymTable.existsSymbol($1) )
		{
            cat::parse::fdeferror(_g_lineCount, "Duplicate function name");
			_g_functionDefError = true;
			_g_semanticError = true;
		}
		
		_g_funcTable.setName($1);
		
		
		// !!TODO!!
		// If repeated function name with same argument pattern,
		// then it is a duplicate definition. Report error.


	}
	;

parameter_list
	: parameter_declaration
	| parameter_list ',' parameter_declaration 
	;

parameter_declaration
	: type_specifier declarator 
	{
		if(!_g_declaratorError)
		{
		    _g_curVarType->setPrimitive(_g_typeSpec);
		
		    VarDeclaration v;
		    v.setDeclType(PARAM);
		    v.setName(_g_currentId);
		    v.setSize(_g_size);
		    v.setOffset(_g_offset);
		    v.setVarType(_g_varType);
		    _g_funcTable.addParam(v);
		
		    _g_offset += _g_size;
		}
		else
		{
		    _g_functionDefError = true;
			_g_semanticError = true;
			_g_declaratorError = false;
		}
	}		
	;

declarator
	: TOK_IDENTIFIER 
	{
	    if(_g_funcTable.existsSymbol($1)
	        || _g_globalSymTable.existsSymbol($1))
	    {
	        _g_declaratorError = true;
	        cat::parser::declatorerror(_g_lineCount, "Duplicate identifiers used");
	    }
	    else
	    {
		    _g_currentId = $1;
		    _g_varType = new VarType();
		    _g_varType
		    _g_curVarType = _g_varType;
		    _g_size = _g_width;
		}
	}
	| declarator '[' TOK_INT_CONST ']'  // Changed constant expr to INT_CONST
	{
	
	    if(std::stoi($3) == 0)
	    {
	        _g_declaratorError = true;
	        cat::parser::declatorerror(_g_lineCount, "Zero size array not allowed");
	    }
	    
	    if(!_g_declaratorError)
	    {
		    _g_curVarType->setArray(stoi($3)); 
		    _g_curVarType->setNestedVarType(new VarType());
		    _g_curVarType = _g_curVarType->getNestedVarType();
		    _g_size *= (stoi($3));
		}
	}
        ;

constant_expression 
        : TOK_INT_CONST
        | TOK_FP_CONST 
        ;

compound_statement
	: '{' '}' 
	| '{' statement_list '}'
	{
		//($2)->print(); //Uncomment to print the ADT
		//std::cout <<'\n'; 
	} 
	| '{' declaration_list statement_list '}'
	{
		//($3)->print(); //Uncomment to print the ADT 
		//std::cout << '\n';
	} 
	;

statement_list
	: statement
	{
		($$) = new Block($1);
		($$).setValidAST(($1).getValidAST());
	}
    | statement_list statement	
    {
		((Block*)($1))->insert($2);
		($$).setValidAST(($1).getValidAST() && ($2).getValidAST());
		($$) = ($1);
	}
	;

statement
        : '{' statement_list '}'
        {
			($$) = ($2);
		    ($$).setValidAST(($2).getValidAST());
        }  //a solution to the local decl problem
        | selection_statement 	
        {
			($$) = ($1);
			($$).setValidAST(($1).getValidAST());
        }
        | iteration_statement
        {
			($$) = ($1);
			($$).setValidAST(($1).getValidAST());
        } 	
		| assignment_statement	
		{
			($$) = ($1);
			($$).setValidAST(($1).getValidAST());
		}
        | TOK_RETURN_KW expression ';'	
        {
            ($$) = new Return( ($2) );
            
            if( ($2).getValidAST() && 
                retTypeCompatible(_g_funcTable.getReturnType(), ($2).getValType())
            {
			    ($$).setValidAST(true);
			}
			else if(($2).getValidAST())
			{
			    ($$).setValidAST(false);
			    _g_funcDefError = true;
			    cat::parse::fdeferror(_g_lineCount, "Return type does not match");
			}
			else
			{
			    ($$).setValidAST(false);
			    _g_funcDefError = true;   
			}
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
	    if( ($1).getValidAST() && ($2).getValidAST() && 
	        assTypeCompatible(($1).getValType(), ($3).getValType()))
	    {
            ($$).setValidAST(true);
		}
		else if(($1).getValidAST() && ($2).getValidAST())
		{
		    ($$).setValidAST(false);
		    _g_funcDefError = true;
		    cat::parse::stmterror(_g_lineCount, "Incompatible types");
		}
		else
		{
		    ($$).setValidAST(false);
		    _g_funcDefError = true;
		}
		    
	}
	;

expression
	: logical_and_expression
	{
		$$ = $1;
	} 
	| expression TOK_LOR_OP logical_and_expression
	{
	    if(!_g_exprError &&
	        orTypeCompatible(($1).getValType(), ($3).getValType()))
	    {
		    $$ = new BinaryOp($1, $3, OR);
		    ($$).setValType(EXP_VAL_INT);
		}
		else if(!_g_exprError)
		{
		    _g_funcDefError = true;
		    _g_exprError = true;
		    cat::parse::stmterror(_g_lineCount, "Incompatible types");
		}
	}
	;

logical_and_expression
	: equality_expression
	{
		$$ = $1;
	}
	| logical_and_expression TOK_LAND_OP equality_expression
	{
		$$ = new BinaryOp($1, $3, AND);
	} 
	;

equality_expression
	: relational_expression
	{
		$$ = $1;
	} 
	| equality_expression TOK_EQ_OP relational_expression
    {
		$$ = new BinaryOp($1, $3, EQ_OP);
	} 	
	| equality_expression TOK_NEQ_OP relational_expression
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
	| relational_expression TOK_LEQ_OP additive_expression
	{
		$$ = new BinaryOp($1, $3, LE_OP);
	}  
    | relational_expression TOK_GEQ_OP additive_expression 
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
    | TOK_IDENTIFIER '(' ')'
    {
		$$ = new FunCall(nullptr);
		((FunCall*)($$))->setName($1);
	}
	| TOK_IDENTIFIER '(' expression_list ')' 
	{
		$$ = $3;
		((FunCall*)($3))->setName($1);
	}
	| l_expression TOK_INCR_OP
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
	| TOK_INT_CONST
	{
		$$ = new IntConst(std::stoi($1));
	}
	| TOK_FP_CONST
	{
		$$ = new FloatConst(std::stof($1));
	}
    | TOK_STR_CONST
    {
		$$ = new StringConst((std::string)$1);
    }
	| '(' expression ')' 
	{
		$$ = $2;
	}	
	;

l_expression
        : TOK_IDENTIFIER
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
        : TOK_IF_KW '(' expression ')' statement TOK_ELSE_KW statement 
		{
			($$) = new If( ($3), ($5), ($7));
		}
	;

iteration_statement
	: TOK_WHILE_KW '(' expression ')' statement 
	{
		($$) = new While( ($3), ($5));
	}
    | TOK_FOR_KW '(' expression ';' expression ';' expression ')' statement  //modified this production
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
	{
		_g_curVarType->setPrimitive(_g_typeSpec);
		VarDeclaration v;
		v.setDeclType(LOCAL);
		v.setName(_g_currentId);
		v.setSize(_g_size);
		v.setOffset(_g_offset);
		v.setVarType(_g_varType);
		_g_funcTable.addVar(v);
		_g_offset += _g_size;
	}
	| declarator_list ',' declarator 
	{
		_g_curVarType->setPrimitive(_g_typeSpec);
		VarDeclaration v;
		v.setDeclType(LOCAL);
		v.setName(_g_currentId);
		v.setSize(_g_size);
		v.setOffset(_g_offset);
		v.setVarType(_g_varType);
		_g_funcTable.addVar(v);
		_g_offset += _g_size;
	}
	;



