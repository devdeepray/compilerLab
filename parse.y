%scanner Scanner.h 
%scanner-token-function d_scanner.lex() 
%token TOK_FP_CONST TOK_INT_CONST TOK_VOID_KW TOK_INT_KW TOK_FLOAT_KW TOK_FOR_KW 
%token TOK_WHILE_KW TOK_IF_KW TOK_ELSE_KW TOK_RETURN_KW TOK_IDENTIFIER 
%token TOK_LEQ_OP TOK_GEQ_OP TOK_INCR_OP TOK_STR_CONST 
%token TOK_LAND_OP TOK_LOR_OP TOK_EQ_OP TOK_NEQ_OP 
%polymorphic   expAstPtr: ExpAst*;
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

translation_unit  : function_definition
{
    // _g_globalSymTable.print();
}
| translation_unit function_definition
{
    // _g_globalSymTable.print();
}
;
function_definition  : type_specifier
{
    /*  
    * This part of the code will be reached at the beginning  
    * of a function definition (after reducing the type specifier).   
    * Start a new function table at this point.   
    * Assume all errors except glob errors are false  */    
    _g_offset = 0;
    _g_funcTable.reset();
    _g_funcTable.setReturnType(_g_typeSpec);
    _g_functionStartLno = _g_lineCount;
}
fun_declarator compound_statement
{
    /*  
    * After the function has been processed.   
    * _g_functionDecError will be true if there was an error in declarator. 
    * If compound statement has error, that is not fdec error
    */  
    
    // Do these regardless of error
    // Fix offsets 
    _g_funcTable.correctOffsets();
      
    // Add to table
    _g_globalSymTable.addFuncTable(_g_funcTable);
        
    if(_g_functionDecError)// Function declaration was bad
    {
        cat::parse::fdecerror(_g_functionStartLno, _g_funcTable.getSignature());
    }
    
    // Set function and declaration errors to false  
    _g_semanticError = _g_semanticError || _g_functionDecError;
    _g_functionDecError = false;
}
;
type_specifier  : TOK_VOID_KW
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
fun_declarator  : TOK_IDENTIFIER '(' parameter_list ')'
{
    
    if( _g_globalSymTable.existsSameSignature(_g_funcTable) )
    {
        // Same signature exists   
        cat::parse::fdecerror::funcdupsig(_g_lineCount, _g_funcTable.getSignature());
        _g_functionDecError = true;
    }
    
    // On success or failure, doesnt hurt to set the name  
    _g_funcTable.setName($1);
    _g_offset += 4; // Address bytes of machine for ebp
}
| TOK_IDENTIFIER '(' ')'
{
    if( _g_globalSymTable.existsSameSignature(_g_funcTable) )
    {
        cat::parse::fdecerror(_g_lineCount, _g_funcTable.getSignature());
        _g_functionDecError = true;
    }
    
    _g_funcTable.setName($1);
    _g_offset += 4; // Address bytes of machine for ebp
}
;
parameter_list  : parameter_declaration  
| parameter_list ',' parameter_declaration   
;
parameter_declaration  : type_specifier declarator
{
    // Whether decl wrong or right semantically, store it
        _g_curVarType->setPrimitive(_g_typeSpec);
        // Innermost type of non primitive     
        VarDeclaration v;
        v.setDeclType(PARAM);
        v.setName(_g_currentId);
        v.setSize(_g_size);
        v.setOffset(_g_offset);
        v.setVarType(_g_varType);
        _g_funcTable.addParam(v);
        _g_offset += _g_size;
	  
	_g_functionDecError = _g_functionDecError || _g_declarationError;  
	_g_declarationError = false; // Reset declaration error for next one
}
;
declarator  : TOK_IDENTIFIER
{
    if(_g_funcTable.existsSymbol($1))
    {
        _g_declarationError = true;
        cat::parser::declatorerror::dupid(_g_lineCount, $1);
    }
    
    
    _g_currentId = $1;
    _g_varType = new VarType();
    _g_varType   _g_curVarType = _g_varType;
    _g_size = _g_width;
  
}
| declarator '[' TOK_INT_CONST ']' // Changed constant expr to INT_CONST
{
    if(std::stoi($3) == 0)
    {
        _g_declarationError = true;
        cat::parser::declatorerror::emptyarray(_g_lineCount, _g_currentId);
    }
    _g_curVarType->setArray(stoi($3));
    _g_curVarType->setNestedVarType(new VarType());
    _g_curVarType = _g_curVarType->getNestedVarType();
    _g_size *= (stoi($3));
}
;
constant_expression   : TOK_INT_CONST  
| TOK_FP_CONST   
;
compound_statement  : '{' '}'   
|'{' statement_list '}'
{
    //($2)->print();
    //Uncomment to print the ADT  //std::cout <<'n';
    _g_semanticError = _g_semanticError || ($2).validAST();
}
| '{' declaration_list statement_list '}'
{
    //($3)->print();
    //Uncomment to print the ADT   //std::cout << 'n';
    _g_semanticError = _g_semanticError || ($2).validAST();
}
;
statement_list  : statement
{
    ($$) = new Block($1); // New list of statements  
    ($$).validAST = ($1).validAST; // Valid if each stmt is valid
}
| statement_list statement
{
    ((Block*)($1))->insert($2); // Insert into orig list  
    ($$).validAST = ($1).validAST() && ($2).validAST(); // Update validity  
    ($$) = ($1); // Set current list to longer list
}
;
statement  : '{' statement_list '}'
{
    ($$) = ($2);
}
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
| TOK_RETURN_KW expression ';'
{
    ($$) = new Return( ($2) );
    
    bool retComp = retTypeCompatible(_g_funcTable.getReturnType(), ($2).valType());
    ($$).validAST() = ($2).validAST() && retComp;
	
    if(!retComp)
    {
        cat::parse::stmterror::rettypeerror(_g_lineCount);
    }
}
;
assignment_statement  : ';'
{
    $$ = new Empty();
}
| l_expression '=' expression ';'
{
    $$ = new Ass($1, $3);
    
    bool comp = assTypeCompatible(($1).valType(), ($3).valType());
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = ($1).valType();
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompasstype(_g_lineCount, ($1).valType(), ($3).valType());
    }
}
;
expression  : logical_and_expression
{
    ($$) = ($1);
}
| expression TOK_LOR_OP logical_and_expression
{
    $$ = new BinaryOp($1, $3, OR);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_OR);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_OR);
    }
}
;
logical_and_expression  : equality_expression
{
    $$ = $1;
}
| logical_and_expression TOK_LAND_OP equality_expression
{
    $$ = new BinaryOp($1, $3, OP_AND);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_AND);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong  type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_AND);
    }
}
;
equality_expression  : relational_expression
{
    $$ = $1;
}
| equality_expression TOK_EQ_OP relational_expression
{
   $$ = new BinaryOp($1, $3, OP_EQ);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_EQ);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_EQ);
    }
}
| equality_expression TOK_NEQ_OP relational_expression
{
    $$ = new BinaryOp($1, $3, OP_NE);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_NE);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_NE);
    }
}
;
relational_expression  : additive_expression
{
    $$ = $1;
}
| relational_expression '<' additive_expression
{
    $$ = new BinaryOp($1, $3, OP_LT);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_LT);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_LT);
    }
}
| relational_expression '>' additive_expression
{
    $$ = new BinaryOp($1, $3, OP_GT);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_GT);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_GT);
    }
}
| relational_expression TOK_LEQ_OP additive_expression
{
    $$ = new BinaryOp($1, $3, OP_LE);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_LE);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_LE);
    }
}
| relational_expression TOK_GEQ_OP additive_expression
{
    $$ = new BinaryOp($1, $3, OP_GE);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_GE);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = TYPE_INT;
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_GE);
    }
}
;
additive_expression   : multiplicative_expression
{
    $$ = $1;
}
| additive_expression '+' multiplicative_expression
{

    $$ = new BinaryOp($1, $3, OP_PLUS);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_PLUS);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = getDominantType( ($1).valType(), ($3).valType()); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_PLUS);
    }
    
}
| additive_expression '-' multiplicative_expression
{
    $$ = new BinaryOp($1, $3, OP_MINUS);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_MINUS);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = getDominantType( ($1).valType(), ($3).valType()); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_MINUS);
    }
}
;
multiplicative_expression  : unary_expression
{
    $$ = $1;
}
| multiplicative_expression '*' unary_expression
{
    $$ = new BinaryOp($1, $3, OP_MULT);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_MULT);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = getDominantType( ($1).valType(), ($3).valType()); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_MULT);
    }
}
| multiplicative_expression '/' unary_expression
{
    $$ = new BinaryOp($1, $3, OP_DIV);
    
    bool comp = binOpTypeCompatible(($1).valType(), ($3).valType(), OP_DIV);
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = getDominantType( ($1).valType(), ($3).valType()); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompboptype(_g_lineCount, ($1).valType(), ($3).valType(), OP_DIV);
    }
}
;
unary_expression  : postfix_expression
{
    $$ = $1;
}
| unary_operator postfix_expression
{

    $$ = new UnaryOp($1, $2);
    
    bool comp = unaryOpCompatible($1, ($2).valType());
    
    ($$).validAST() = ($2).validAST() && comp;
    ($$).valType() = ($2).valType(); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::invalidunop(_g_lineCount, $1, ($2).valType());
    }
    
}
;
postfix_expression  : primary_expression
{
    $$ = $1;
}
| TOK_IDENTIFIER '(' ')'
{
    $$ = new FunCall(nullptr);
    // No args fun call  
    ((FunCall*)($$))->setName($1);
    ($$).valType() = TYPE_WEAK;
    
    if(_g_globalSymTable.existsFuncDefinition($1, list<ValType>())
    {
        // Valid function call  
        ($$).validAST() = true;
        ($$).valType() = _g_globalSymTable.getFuncTable($1, list<ValType>()).getReturnType();
    }
    else
    {
        ($$).validAST() = false;
        cat::parse::fdecerror::badfcall(_g_lineCount, $1, list<ValType>());
    }
}
| TOK_IDENTIFIER '(' expression_list ')'
{
    $$ = $3;
    ((FunCall*)($3))->setName($1);
    ($$).valType() = TYPE_WEAK;
    
    if(($3).validAST() && _g_globalSymTable.existsFuncDefinition($1, ($3).getArgTypeList()))
    {
        ($$).validAST() = true;
        ($$).valType() = _g_globalSymTable.getFuncTable($1, list<ValType>()).getReturnType();
    }
    else if(($3).validAST())
    {
        ($$).validAST() = false;
        cat::parse::fdecerror::badfcall(_g_lineCount, $1, ($3).getArgTypeList());
    }
}
| l_expression TOK_INCR_OP
{


    $$ = new UnaryOp($1, OP_PP);
    
    bool comp = unaryOpCompatible(OP_PP, ($1).valType());
    
    ($$).validAST() = ($1).validAST() && comp;
    ($$).valType() = ($1).valType(); 
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::invalidunop(_g_lineCount, OP_PP, ($1).valType());
    }
    
}
;
primary_expression  : l_expression
{
    $$ = $1;
}
| l_expression '=' expression // added this production
{
    $$ = new Ass($1, $3);
    
    bool comp = assTypeCompatible(($1).valType(), ($3).valType());
    
    ($$).validAST() = ($1).validAST() && ($3).validAST() && comp;
    ($$).valType() = ($1).valType();
    
    if(!comp)
    {
        // Wrong assignment type mismatch   
        cat::parse::stmterror::incompasstype(_g_lineCount, ($1).valType(), ($3).valType());
    }
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
l_expression  : TOK_IDENTIFIER
{
    $$ = new Identifier($1);
    // Check for this symbol in the local symbol table
    ($$).valType = TYPE_WEAK;
    
    if(_g_funcTable.existsSymbol($1))
    {
      ($$).validAST() = true;
      
      if(_g_funcTable.getVar($1).varType->primitive)
      {
	($$).valType() = (_g_funcTable.getVar($1).varType())->type;
      }
      else
      {
	_g_curVarType = _g_funcTable.getVar($1).varType();
      }
    }
    else
    {
      ($$).validAST() = false;
      cat::parser::stmterror::symbolnotfound(_g_lineCount, $1, _g_funcTable);
    }
}
| l_expression '[' expression ']'
{
    
    if(($1).validAST())
    {
      $$ = new Index($1, $3);
      bool canIndex = !(_g_curVarType->primitive);
      ($$).validAST() = ($2).validAST() && canIndex;
      
      if(!canIndex)
      {
	cat::parser::stmterror::arrayreferror(_g_lineCount, _g_currentId);
      }
      else
      {
	  _g_curVarType = _g_curVarType->getNestedVarType();
      }
    }
    else
    {
      ($$) = ($1);
    }
}
;
expression_list  : expression
{
    $$ = new FunCall($1);
}
| expression_list ',' expression
{
    ((FunCall*)($1))->insert($3);
    $$ = $1;
}
;
unary_operator  : '-'
{
    $$ = UMINUS;
}
| '!'
{
    $$ = NOT;
}
;
selection_statement  : TOK_IF_KW '(' expression ')' statement TOK_ELSE_KW statement
{
    ($$) = new If( ($3), ($5), ($7));
}
;
iteration_statement  : TOK_WHILE_KW '(' expression ')' statement
{
    ($$) = new While( ($3), ($5));
}
| TOK_FOR_KW '(' expression ';
' expression ';
' expression ')' statement //modified this production
{
    ($$) = new For( ($3), ($5), ($7), ($9));
}
;
declaration_list  : declaration    
| declaration_list declaration  
;

declaration  : type_specifier declarator_list';'  ;

declarator_list  : declarator
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
    
    
    _g_varDecError = _g_varDecError || _g_declarationError;
    _g_declarationError = false;
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
    
    _g_varDecError = _g_varDecError || _g_declarationError;
    _g_declarationError = false;
}
;
