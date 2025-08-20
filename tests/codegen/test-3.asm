This is PINS'24 compiler (code generation):
Program:
  FunDef main [1.1:7.7] depth=1 parsSize=4 varsSize=20
      --- Code: ---
      LABEL main
        PUSH -12
        POPN
        REGN.FP
        PUSH -16
        OPER.ADD
        NAME :0
        INIT
        REGN.FP
        PUSH -20
        OPER.ADD
        NAME :1
        INIT
        PUSH 10
        REGN.FP
        LOAD
        NAME inc
        CALL
        PUSH 0
        RETN
    Pars:
    Stmts:
      LetStmt [2.5:7.7]
          --- Code: ---
            REGN.FP
            PUSH -16
            OPER.ADD
            NAME :0
            INIT
            REGN.FP
            PUSH -20
            OPER.ADD
            NAME :1
            INIT
            PUSH 10
            REGN.FP
            LOAD
            NAME inc
            CALL
            PUSH 4
            POPN
        LetDefs:
          VarDef x [3.9:3.17] offset=-16 size=8 depth=1 inits=3,4
              --- Code: ---
                REGN.FP
                PUSH -16
                OPER.ADD
                NAME :0
                INIT
              --- Data: ---
              LABEL :0
                DATA 2
                DATA 1
                DATA 1
                DATA 3
                DATA 1
                DATA 1
                DATA 4
            Inits:
              Init 1* [3.15:3.15]
                AtomExpr INTCONST(3) [3.15:3.15]
              Init 1* [3.17:3.17]
                AtomExpr INTCONST(4) [3.17:3.17]
          VarDef i [4.9:4.15] offset=-20 size=4 depth=1 inits=0
              --- Code: ---
                REGN.FP
                PUSH -20
                OPER.ADD
                NAME :1
                INIT
              --- Data: ---
              LABEL :1
                DATA 1
                DATA 1
                DATA 1
                DATA 0
            Inits:
              Init 1* [4.15:4.15]
                AtomExpr INTCONST(0) [4.15:4.15]
        LetStmts:
          ExprStmt [6.9:6.15]
              --- Code: ---
                PUSH 10
                REGN.FP
                LOAD
                NAME inc
                CALL
                PUSH 4
                POPN
            CallExpr inc [6.9:6.15] def@[9.1:9.14]
                --- Code: ---
                  PUSH 10
                  REGN.FP
                  LOAD
                  NAME inc
                  CALL
              Args:
                AtomExpr INTCONST(10) [6.13:6.14]
                    --- Code: ---
                      PUSH 10
  FunDef inc [9.1:9.14] depth=1 parsSize=8 varsSize=8
      --- Code: ---
      LABEL inc
        PUSH 0
        POPN
        REGN.FP
        PUSH 4
        OPER.ADD
        LOAD
        PUSH 1
        OPER.ADD
        PUSH 4
        RETN
    Pars:
      ParDef n [9.9:9.9] offset=4 size=4 depth=1
    Stmts:
      ExprStmt [9.12:9.14]
          --- Code: ---
            REGN.FP
            PUSH 4
            OPER.ADD
            LOAD
            PUSH 1
            OPER.ADD
            PUSH 4
            POPN
        BinExpr ADD [9.12:9.14]
            --- Code: ---
              REGN.FP
              PUSH 4
              OPER.ADD
              LOAD
              PUSH 1
              OPER.ADD
          NameExpr n [9.12:9.12] def@[9.9:9.9] lval
              --- Code: ---
                REGN.FP
                PUSH 4
                OPER.ADD
                LOAD
          AtomExpr INTCONST(1) [9.14:9.14]
              --- Code: ---
                PUSH 1
  VarDef y [11.1:11.9] size=8 inits=5,5
      --- Code: ---
        NAME y
        NAME :2
        INIT
      --- Data: ---
      LABEL y
        SIZE 8
      LABEL :2
        DATA 1
        DATA 2
        DATA 1
        DATA 5
    Inits:
      Init 2* [11.7:11.9]
        AtomExpr INTCONST(5) [11.9:11.9]
  FunDef putstr [13.1:13.19] depth=1 parsSize=8 varsSize=8
    Pars:
      ParDef straddr [13.12:13.18] offset=4 size=4 depth=1
    Stmts:
  FunDef putint [14.1:14.20] depth=1 parsSize=8 varsSize=8
    Pars:
      ParDef intvalue [14.12:14.19] offset=4 size=4 depth=1
    Stmts:

CODE SEGMENT:
       0 [5]   NAME y
       5 [5]   NAME :2
      10 [1]   INIT
      11 [5]   PUSH 0
      16 [5]   NAME main
      21 [1]   CALL
      22 [5]   PUSH 0
      27 [5]   NAME exit
      32 [1]   CALL
      33 [0] LABEL main
      33 [5]   PUSH -12
      38 [1]   POPN
      39 [1]   REGN.FP
      40 [5]   PUSH -16
      45 [1]   OPER.ADD
      46 [5]   NAME :0
      51 [1]   INIT
      52 [1]   REGN.FP
      53 [5]   PUSH -20
      58 [1]   OPER.ADD
      59 [5]   NAME :1
      64 [1]   INIT
      65 [5]   PUSH 10
      70 [1]   REGN.FP
      71 [1]   LOAD
      72 [5]   NAME inc
      77 [1]   CALL
      78 [5]   PUSH 0
      83 [1]   RETN
      84 [0] LABEL inc
      84 [5]   PUSH 0
      89 [1]   POPN
      90 [1]   REGN.FP
      91 [5]   PUSH 4
      96 [1]   OPER.ADD
      97 [1]   LOAD
      98 [5]   PUSH 1
     103 [1]   OPER.ADD
     104 [5]   PUSH 4
     109 [1]   RETN

DATA SEGMENT:
     110 [0] LABEL :0
     110 [4]   DATA 2
     114 [4]   DATA 1
     118 [4]   DATA 1
     122 [4]   DATA 3
     126 [4]   DATA 1
     130 [4]   DATA 1
     134 [4]   DATA 4
     138 [0] LABEL :1
     138 [4]   DATA 1
     142 [4]   DATA 1
     146 [4]   DATA 1
     150 [4]   DATA 0
     154 [0] LABEL y
     154 [ ]   SIZE 8
     162 [0] LABEL :2
     162 [4]   DATA 1
     166 [4]   DATA 2
     170 [4]   DATA 1
     174 [4]   DATA 5

:-) Done.
