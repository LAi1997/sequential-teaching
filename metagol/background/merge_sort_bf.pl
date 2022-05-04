%% composite data structure

%% Learning robot sorting algorithm taken from the following paper:
%% A. Cropper and S.H. Muggleton. Learning efficient logical robot strategies involving composable objects. In Proceedings of the 24th International Joint Conference Artificial Intelligence (IJCAI 2015), pages 3423-3429. IJCAI, 2015.
%% Some first-order background knowledge inherited from https://github.com/metagol/metagol/blob/master/examples/sorter.pl
:- use_module(library(random)).
:- use_module(library(system)).

%% check if an attribute is specified in the current world (state)
%% <values:list, energy:int, robot_pos:int, intervals:list, holding_left:int, holding_right:int, left_memory:list, right_memory:list>
world_check(X,A):-
    nonvar(A),
    member(X,A),!.

%% replace an attribute value that was specified in the world state
world_replace(X,Y,A,B):-
    nonvar(A),
    nonvar(B),!,
    append(Prefix,[X|Suffix],A),
    append(Prefix,[Y|Suffix],B),!.
world_replace(X,Y,A,B):-
    nonvar(A),
    append(Prefix,[X|Suffix],A),
    append(Prefix,[Y|Suffix],B),!.

%% check the data structure/type of attributes and list elem
elem_type_check(A):-
    integer(A).
attr_type_check(A):-
    is_list(A),
    member(E,A),!,
    integer(E).
attr_type_check(A):-
    is_list(A).

%% definition of item order, used for item comparison
order_leq(A,B):-A=<B.
order_gt(A,B):-A>B.

%% count the number of item pairs that are out of order, complexity O(n^2)
inversions([_],0):-!.
inversions([H|T],K):-
    inversions(H,T,N),
    inversions(T,N1),
    K is N+N1.
inversions(_,[],0).
inversions(U,[H|T],I):-
    order_leq(U,H),!,
    inversions(U,T,I).
inversions(U,[_|T],I):-
    inversions(U,T,I1),
    I is I1+1.

%% assume learner knows lexicographic order of numbers from 0 to 50
lexi_order([0,1,2,3,4,5,6,7,8,9,
            10,11,12,13,14,15,16,17,18,19,
            20,21,22,23,24,25,26,27,28,29,
            30,31,32,33,34,35,36,37,38,39,
            40,41,42,43,44,45,46,47,48,49,
            50]).

compute_spearman(L,C):-
    lexi_order(Order),
    findall(Num,(member(Num,Order),member(Num,L)),LocalOrder),
    spearman_rank(L,LocalOrder,1,SumXY,SumX,SumY,_,_,Length),
    C is Length*SumXY-SumX*SumY.

spearman_rank([],_,_,0,0,0,0,0,0).
spearman_rank([H|T],L,Rank,SumXY,SumX,SumY,SumXSq,SumYSq,Size):-
    nth1(R,L,H),!,
    square(R,RS),
    square(Rank,RankS),
    Rank1 is Rank+1,
    spearman_rank(T,L,Rank1,SumXY1,SumX1,SumY1,SumXSq1,SumYSq1,Size1),
    SumX is SumX1+Rank,
    SumXSq is SumXSq1+RankS,
    SumY is SumY1+R,
    SumYSq is SumYSq1+RS,
    SumXY is Rank*R+SumXY1,
    Size is Size1+1.

square(X,Y):-
    Y is X*X.

%% Terms (world states) are ordered to ensure values in the next state is not less sorted
%% Compare the number of value inversions in two consecutive states
term_order(inversions,A,B):-
    world_check(values(V1),A),
    world_check(values(V2),B),
    inversions(V1,K1),
    inversions(V2,K2),
    K1 >= K2.

%% Compare the spearman rank coff of values in two consecutive states, ro<V1,L> and ro<V2,L>
%% where L is the lexicographic order of elements in V1 and V2
%% higher spearman value = more sorted
%% skipping computation of the constant denominator
term_order(spearman,A,B):-
    world_check(values(V1),A),
    world_check(values(V2),B),
    compute_spearman(V1,C1),
    compute_spearman(V2,C2),
    C1 < C2.

%% ENERGY COSTS
%increment_energy(A,B,Amount):-
%    energy_bound(Bound),!,
%    world_check(energy(E1),A),
%    E2 is E1+Amount,
%    E2 =< Bound,
%    world_replace(energy(E1),energy(E2),A,B).

increment_energy(A,B,Amount):-
    world_check(energy(E1),A),
    E2 is E1+Amount,
    world_replace(energy(E1),energy(E2),A,B).

record_energy(A,Amount):-
    world_check(energy(Amount),A).

%% actions to identify, replace and get a value from a world state
value_at(A,Index,Value):-
    world_check(values(L),A),
    nth1(Index,L,Value).

value_replace_at(A,B,I,X) :-
    world_check(values(L),A),
    Dummy =..[dummy|L],
    J is I,
    setarg(J,Dummy,X),
    Dummy =..[dummy|R],
    world_replace(values(L),values(R),A,B).

pop_value(A,B,Value):-
    world_check(robot_pos(Pos),A),
    value_at(A,Pos,Value),
    Value \= none,
    elem_type_check(Value),
    value_replace_at(A,B,Pos,none).

%% check if values, left temp and right temp are empty
left_memory_empty(A,A):-
    world_check(left_memory([]),A).
right_memory_empty(A,A):-
    world_check(right_memory([]),A).
values_empty(A,A):-
    world_check(values(Values),A),
    forall(member(E,Values),E==none).

%% identify the position of robot (pointer to a value)
start_pos(A,StartPos):-
    world_check(intervals([StartPos-_|_]),A).

end_pos(A,EndPos):-
    world_check(intervals([_-EndPos|_]),A).

at_start_pos(A):-
    start_pos(A,X),
    robot_pos(A,X).

at_end_pos(A):-
    end_pos(A,X),
    robot_pos(A,X).

robot_pos(A,X):-
    world_check(robot_pos(X),A).

%% actions for the robot to move around and switch focus at values
go_to(A,A,Pos):-
  world_check(robot_pos(Pos),A),!.

go_to(A,B,Pos):-
  world_check(robot_pos(X1),A),
  X1 < Pos,!,
  move_right(A,C),
  go_to(C,B,Pos).

go_to(A,B,Pos):-
  world_check(robot_pos(X1),A),
  X1 > Pos,!,
  move_left(A,C),
  go_to(C,B,Pos).

go_to_start(A,B):-
    start_pos(A,X),
    go_to(A,B,X).

go_to_end(A,B):-
    end_pos(A,X),
    go_to(A,B,X).

move_right(A,B):-
    at_end_pos(A),!,B=A.
move_right(A,B):-
    world_check(robot_pos(X1),A),
    end_pos(A,EndPos),
    X2 is X1+1,
    X2 =< EndPos,
    world_replace(robot_pos(X1),robot_pos(X2),A,B).

move_left(A,B):-
    at_start_pos(A),!,B=A.
move_left(A,B):-
    world_check(robot_pos(X1),A),
    start_pos(A,StartPos),
    X2 is X1-1,
    X2 >= StartPos,
    world_replace(robot_pos(X1),robot_pos(X2),A,B).

%% background for split %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% uses intervals to denote sub-sets from splitting
%% the left memory stores interval for the left half of split
extend_left_sub_interval(A,B):-
    world_check(left_memory([L-H]),A),
    world_check(intervals([_-HB|_]),A),
    succ(H,H1),
    H1 =< HB,
    world_replace(left_memory(_),left_memory([L-H1]),A,B).
%% the right memory stores interval for the right half of split
extend_right_sub_interval(A,B):-
    world_check(right_memory([L-H]),A),
    world_check(intervals([LB-_|_]),A),
    succ(L1,L),
    L1 >= LB,
    world_replace(right_memory(_),right_memory([L1-H]),A,B).

%% memorises the left sub-interval and extends it to the right
move_attention_left(A,B):-
    world_check(left_memory([]),A),!,
    world_check(intervals([L-_|_]),A),
    world_replace(left_memory([]),left_memory([L-L]),A,B).
move_attention_left(A,B):-
    extend_left_sub_interval(A,B).

%% memorises the right sub-interval and extends it to the left
move_attention_right(A,B) :-
    world_check(right_memory([]),A),!,
    world_check(intervals([_-H|_]),A),
    world_replace(right_memory([]),right_memory([H-H]),A,B).
move_attention_right(A,B) :-
    extend_right_sub_interval(A,B).

%% add intervals for the left and right halves of split
record_intervals(A,B):-
    \+ left_memory_empty(A,A),
    \+ right_memory_empty(A,A),
    world_check(left_memory([L1-H1]),A),
    world_check(right_memory([L2-H2]),A),
    succ(H1,L2),
    world_replace(left_memory(_),left_memory([]),A,C),
    world_replace(right_memory(_),right_memory([]),C,D),
    world_check(intervals([I|T]),A),
    append(T,[L1-H1,L2-H2,I],T1),
    world_replace(intervals(_),intervals(T1),D,B).

%% learned program for split
%% minimal input size = two, e.g. split_tradic([1,3],[1],[3])
split(A,B):-move_attention_left(A,C),record_intervals(C,B).
split(A,B):-split_1(A,C),record_intervals(C,B).
split(A,B):-split_1(A,C),split(C,B).
split_1(A,B):-move_attention_left(A,C),move_attention_right(C,B).

%% background for merge %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% left hand picks and puts into left memory (FIFO queue)
%% right hand picks and puts into right memory (FILO stack)
%% e.g. [1,2,3,...,9,10] is split into left [1,2,...>] and right [<...,9,10]
%% in which "...>"/"<..." denotes the direction for filling in rest of the numbers
pick_up_left(A,B):-
    world_check(holding_left(none),A),!,
    pop_value(A,C,Value),
    world_replace(holding_left(none),holding_left(Value),C,B).
pick_up_left(A,A):-
    world_check(holding_left(_),A).

pick_up_right(A,B):-
    world_check(holding_right(none),A),!,
    pop_value(A,C,Value),
    world_replace(holding_right(none),holding_right(Value),C,B).
pick_up_right(A,A):-
    world_check(holding_right(_),A).

pocket_left(A,B) :-
    world_check(holding_left(none),A),!,
    pick_up_left(A,C),
    pocket_left(C,D),
    move_right(D,B).
pocket_left(A,B) :-
    world_check(holding_left(Value),A),
    Value \= none,
    world_check(left_memory(L),A),
    append(L,[Value],L1),
    world_replace(left_memory(L),left_memory(L1),A,C),
    world_replace(holding_left(Value),holding_left(none),C,B).

pocket_right(A,B) :-
    world_check(holding_right(none),A),!,
    pick_up_right(A,C),
    pocket_right(C,D),
    move_right(D,B).
pocket_right(A,B) :-
    world_check(holding_right(Value),A),
    Value \= none,
    world_check(right_memory(L),A),
    world_replace(right_memory(L),right_memory([Value|L]),A,C),
    world_replace(holding_right(Value),holding_right(none),C,B).

%% retrive a value from left memory to left hand
retrieve_left(A,B):-
    world_check(holding_left(none),A),!,
    world_check(left_memory([H|T]),A),
    world_replace(left_memory([H|T]),left_memory(T),A,C),
    world_replace(holding_left(none),holding_left(H),C,B).
retrieve_left(A,A):-
    world_check(holding_left(_),A).

%% retrive a value from right memory to right hand
retrieve_right(A,B):-
    world_check(holding_right(none),A),!,
    world_check(right_memory([H|T]),A),
    world_replace(right_memory([H|T]),right_memory(T),A,C),
    world_replace(holding_right(none),holding_right(H),C,B).
retrieve_right(A,A):-
    world_check(holding_right(_),A).

%% compare values in left and right hands (one in each hand)
left_leq_right(A):-
    world_check(holding_left(X),A),
    world_check(holding_right(Y),A),
    X \= none,
    Y \= none,
    order_leq(X,Y).

left_gt_right(A):-
    world_check(holding_left(X),A),
    world_check(holding_right(Y),A),
    X \= none,
    Y \= none,
    order_gt(X,Y).

compare(A,B):-
    retrieve_left(A,C),
    retrieve_right(C,D),
    left_gt_right(D),!,
    drop_right_hand(D,E),
    increment_energy(E,B,1).
compare(A,B):-
    retrieve_left(A,C),
    retrieve_right(C,D),
    left_leq_right(D),!,
    drop_left_hand(D,E),
    increment_energy(E,B,1).

%% load values into left memory and right memory
load_intervals(A,B):-
    go_to_start(A,C),
    load_interval_left(C,D),
    go_to_end(D,E),
    load_interval_right(E,F),
    go_to_start(F,B).

load_interval_left(A,B):-
    left_memory_empty(A,A),!,
    load_interval_left_aux(A,B).
load_interval_left_aux(A,B):-
    at_end_pos(A),!,
    pick_up_left(A,C),
    pocket_left(C,D),
    world_check(intervals([_|T]),D),
    world_replace(intervals(_),intervals(T),D,B).
load_interval_left_aux(A,B):-
    pick_up_left(A,C),
    pocket_left(C,D),
    move_right(D,E),
    load_interval_left_aux(E,B).

load_interval_right(A,B):-
    right_memory_empty(A,A),!,
    load_interval_right_aux(A,B).
load_interval_right_aux(A,B):-
    at_start_pos(A),!,
    pick_up_right(A,C),
    pocket_right(C,D),
    world_check(intervals([_|T]),D),
    world_replace(intervals(_),intervals(T),D,B).
load_interval_right_aux(A,B):-
    pick_up_right(A,C),
    pocket_right(C,D),
    move_left(D,E),
    load_interval_right_aux(E,B).

%% put value in left hand to values
drop_left_hand(A,B):-
    world_check(holding_left(none),A),!,B=A.
drop_left_hand(A,B):-
    world_check(holding_left(V),A),
    V \= none,
    robot_pos(A,Pos),
    value_at(A,Pos,none),
    value_replace_at(A,C,Pos,V),
    move_right(C,D),
    world_replace(holding_left(_),holding_left(none),D,B).

%% put value in right hand to values
drop_right_hand(A,B):-
    world_check(holding_right(none),A),!,B=A.
drop_right_hand(A,B):-
    world_check(holding_right(V),A),
    V \= none,
    robot_pos(A,Pos),
    value_at(A,Pos,none),
    value_replace_at(A,C,Pos,V),
    move_right(C,D),
    world_replace(holding_right(_),holding_right(none),D,B).

%% iteratively put value in left memory to values
drop_left_memory(A,B):-
    left_memory_empty(A,A),!,B=A.
drop_left_memory(A,B):-
    world_check(holding_left(none),A),
    retrieve_left(A,C),
    drop_left_hand(C,D),
    drop_left_memory(D,B).

%% iteratively put value in right memory to values
drop_right_memory(A,B):-
    right_memory_empty(A,A),!,B=A.
drop_right_memory(A,B):-
    world_check(holding_right(none),A),
    retrieve_right(A,C),
    drop_right_hand(C,D),
    drop_right_memory(D,B).

drop_remaining_values(A,B):-
    world_check(holding_left(none),A),
    world_check(holding_right(none),A),
    left_memory_empty(A,A),
    right_memory_empty(A,A),!,B=A.
drop_remaining_values(A,B):-
    world_check(holding_left(none),A),
    left_memory_empty(A,A),!,
    drop_right_hand(A,C),
    drop_right_memory(C,D),
    world_check(intervals([_|T]),D),
    world_replace(intervals(_),intervals(T),D,B).
drop_remaining_values(A,B):-
    world_check(holding_right(none),A),
    right_memory_empty(A,A),
    drop_left_hand(A,C),
    drop_left_memory(C,D),
    world_check(intervals([_|T]),D),
    world_replace(intervals(_),intervals(T),D,B).

%% learned program for merge
merger(A,B):-load_intervals(A,C),merger_2(C,B).
merger_2(A,B):-compare(A,C),merger_2(C,B).
merger_2(A,B):-drop_remaining_values(A,C),drop_remaining_values(C,B).

%% additional background knowledge %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% focus on the next interval that has been recorded
next_interval(A,B):-
    world_check(intervals([_]),A),!,B=A.
next_interval(A,B):-
    world_check(intervals([U1-V1,U2-V2|T]),A),
    world_replace(intervals(_),intervals([U2-V2,U1-V1|T]),A,C),
    go_to_start(C,B).

%% previous definition of the pred
%next_interval(A,B):-
%    world_check(intervals([U1-V1,U2-V2|T]),A),
%    order_gt(U2,V1),
%    world_replace(intervals(_),intervals([U2-V2,U1-V1|T]),A,B).

%% true if the foremost interval contains only one value, e.g. I1-I2 and I1==I2
single_value_interval(A,A):-
    world_check(intervals([I-I|_]),A).
no_intervals(A,A):-
    world_check(intervals([]),A).

%% true if there is one value
single_value(A,A):-
    world_check(values([_]),A).

%% merge sort (hand-written), iterative breadth-first implementation
sorter(A,B):-sorter_1(A,C),sorter_2(C,B).
sorter(A,B):-sorter_1(A,C),sorter_1(C,B).
sorter_1(A,B):-split(A,C),sorter_1(C,B).
sorter_1(A,B):-single_value_interval(A,C),single_value_interval(C,B).
sorter_2(A,B):-merger(A,C),sorter_2(C,B).
sorter_2(A,B):-merger(A,C),no_intervals(C,B).

