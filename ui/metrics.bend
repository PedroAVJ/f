import Base
import ./primitives.bend as P

# Text measurement for Text geometry. Glyph advances of the system UI font
# (SF Pro on Apple devices, the font the canvas and Near use) measured in
# Chrome at 16px for weights 400, 500 and 600, in thousandths of an em. Other
# sizes apply the font's size-specific tracking. Kerning is ignored; the error
# is about 1%. Characters outside the table count as an average glyph.

type Advance is Data:
  Advance{code: U32, regular: U32, medium: U32, semibold: U32}

def advances() -> List<&2, Advance>:
  [Advance{32, 262, 254, 246}, Advance{33, 292, 307, 322}, Advance{34, 458, 488, 519}, Advance{35, 610, 624, 638}, Advance{36, 610, 624, 638}, Advance{37, 906, 942, 979},
   Advance{38, 692, 703, 714}, Advance{39, 277, 294, 311}, Advance{40, 362, 378, 394}, Advance{41, 362, 378, 394}, Advance{42, 452, 457, 460}, Advance{43, 610, 624, 638},
   Advance{44, 277, 294, 311}, Advance{45, 452, 457, 460}, Advance{46, 277, 294, 311}, Advance{47, 285, 295, 305}, Advance{48, 610, 628, 647}, Advance{49, 444, 460, 476},
   Advance{50, 584, 597, 610}, Advance{51, 607, 622, 635}, Advance{52, 624, 639, 653}, Advance{53, 599, 614, 629}, Advance{54, 617, 633, 648}, Advance{55, 569, 581, 593},
   Advance{56, 619, 638, 656}, Advance{57, 617, 633, 648}, Advance{58, 277, 294, 311}, Advance{59, 277, 294, 311}, Advance{60, 610, 624, 638}, Advance{61, 610, 624, 638},
   Advance{62, 610, 624, 638}, Advance{63, 493, 508, 523}, Advance{64, 898, 901, 904}, Advance{65, 654, 674, 693}, Advance{66, 638, 650, 662}, Advance{67, 696, 705, 713},
   Advance{68, 707, 714, 721}, Advance{69, 576, 585, 594}, Advance{70, 553, 561, 569}, Advance{71, 727, 731, 736}, Advance{72, 723, 736, 750}, Advance{73, 248, 265, 282},
   Advance{74, 519, 540, 561}, Advance{75, 639, 656, 673}, Advance{76, 548, 557, 566}, Advance{77, 854, 865, 876}, Advance{78, 723, 731, 740}, Advance{79, 752, 757, 762},
   Advance{80, 616, 628, 641}, Advance{81, 752, 757, 762}, Advance{82, 634, 647, 661}, Advance{83, 618, 630, 643}, Advance{84, 614, 623, 632}, Advance{85, 718, 726, 733},
   Advance{86, 654, 670, 686}, Advance{87, 948, 962, 976}, Advance{88, 659, 676, 693}, Advance{89, 636, 653, 671}, Advance{90, 642, 647, 651}, Advance{91, 362, 378, 394},
   Advance{92, 285, 295, 305}, Advance{93, 362, 378, 394}, Advance{94, 610, 624, 638}, Advance{95, 525, 540, 555}, Advance{96, 480, 480, 480}, Advance{97, 532, 545, 558},
   Advance{98, 595, 607, 620}, Advance{99, 540, 549, 559}, Advance{100, 595, 607, 620}, Advance{101, 552, 562, 571}, Advance{102, 342, 360, 376}, Advance{103, 590, 602, 614},
   Advance{104, 569, 583, 598}, Advance{105, 228, 241, 254}, Advance{106, 227, 241, 254}, Advance{107, 523, 543, 563}, Advance{108, 233, 248, 261}, Advance{109, 851, 871, 892},
   Advance{110, 564, 579, 593}, Advance{111, 571, 581, 590}, Advance{112, 591, 603, 615}, Advance{113, 590, 603, 615}, Advance{114, 371, 387, 404}, Advance{115, 494, 508, 523},
   Advance{116, 344, 362, 380}, Advance{117, 564, 579, 593}, Advance{118, 522, 536, 550}, Advance{119, 755, 779, 803}, Advance{120, 505, 523, 542}, Advance{121, 523, 542, 560},
   Advance{122, 520, 529, 538}, Advance{123, 362, 378, 394}, Advance{124, 239, 253, 266}, Advance{125, 362, 378, 394}, Advance{126, 610, 624, 638}, Advance{191, 493, 508, 523},
   Advance{161, 292, 307, 322}, Advance{225, 532, 545, 558}, Advance{233, 552, 562, 571}, Advance{237, 228, 241, 254}, Advance{243, 571, 581, 590}, Advance{250, 564, 579, 593},
   Advance{241, 564, 579, 593}, Advance{193, 654, 674, 693}, Advance{201, 576, 585, 594}, Advance{205, 248, 265, 282}, Advance{211, 752, 757, 762}, Advance{218, 718, 726, 733},
   Advance{209, 723, 731, 740}, Advance{252, 564, 579, 593}, Advance{183, 277, 294, 311}, Advance{8212, 867, 878, 889}, Advance{8230, 785, 835, 885}]

def weight_of(+weight: U32, +regular: U32, +medium: U32, +semibold: U32) -> U32:
  Bool.pick(U32, U32.is_ge(weight, 600), semibold, Bool.pick(U32, U32.is_ge(weight, 500), medium, regular))
# The table as a binary search: about seven comparisons a glyph.
def look_0_0(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 32), weight_of(weight, 262, 254, 246), 560)
def look_1_1(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 33), weight_of(weight, 292, 307, 322), 560)
def look_2_2(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 34), weight_of(weight, 458, 488, 519), 560)
def pick_1_2(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_1_1(code, weight)
    case False{}: look_2_2(code, weight)
def look_1_2(+code: U32, +weight: U32) -> U32: pick_1_2(U32.is_lt(code, 34), code, weight)
def pick_0_2(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_0(code, weight)
    case False{}: look_1_2(code, weight)
def look_0_2(+code: U32, +weight: U32) -> U32: pick_0_2(U32.is_lt(code, 33), code, weight)
def look_3_3(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 35), weight_of(weight, 610, 624, 638), 560)
def look_4_4(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 36), weight_of(weight, 610, 624, 638), 560)
def pick_3_4(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_3_3(code, weight)
    case False{}: look_4_4(code, weight)
def look_3_4(+code: U32, +weight: U32) -> U32: pick_3_4(U32.is_lt(code, 36), code, weight)
def look_5_5(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 37), weight_of(weight, 906, 942, 979), 560)
def look_6_6(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 38), weight_of(weight, 692, 703, 714), 560)
def pick_5_6(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_5_5(code, weight)
    case False{}: look_6_6(code, weight)
def look_5_6(+code: U32, +weight: U32) -> U32: pick_5_6(U32.is_lt(code, 38), code, weight)
def pick_3_6(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_3_4(code, weight)
    case False{}: look_5_6(code, weight)
def look_3_6(+code: U32, +weight: U32) -> U32: pick_3_6(U32.is_lt(code, 37), code, weight)
def pick_0_6(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_2(code, weight)
    case False{}: look_3_6(code, weight)
def look_0_6(+code: U32, +weight: U32) -> U32: pick_0_6(U32.is_lt(code, 35), code, weight)
def look_7_7(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 39), weight_of(weight, 277, 294, 311), 560)
def look_8_8(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 40), weight_of(weight, 362, 378, 394), 560)
def look_9_9(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 41), weight_of(weight, 362, 378, 394), 560)
def pick_8_9(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_8_8(code, weight)
    case False{}: look_9_9(code, weight)
def look_8_9(+code: U32, +weight: U32) -> U32: pick_8_9(U32.is_lt(code, 41), code, weight)
def pick_7_9(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_7_7(code, weight)
    case False{}: look_8_9(code, weight)
def look_7_9(+code: U32, +weight: U32) -> U32: pick_7_9(U32.is_lt(code, 40), code, weight)
def look_10_10(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 42), weight_of(weight, 452, 457, 460), 560)
def look_11_11(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 43), weight_of(weight, 610, 624, 638), 560)
def pick_10_11(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_10_10(code, weight)
    case False{}: look_11_11(code, weight)
def look_10_11(+code: U32, +weight: U32) -> U32: pick_10_11(U32.is_lt(code, 43), code, weight)
def look_12_12(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 44), weight_of(weight, 277, 294, 311), 560)
def look_13_13(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 45), weight_of(weight, 452, 457, 460), 560)
def pick_12_13(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_12_12(code, weight)
    case False{}: look_13_13(code, weight)
def look_12_13(+code: U32, +weight: U32) -> U32: pick_12_13(U32.is_lt(code, 45), code, weight)
def pick_10_13(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_10_11(code, weight)
    case False{}: look_12_13(code, weight)
def look_10_13(+code: U32, +weight: U32) -> U32: pick_10_13(U32.is_lt(code, 44), code, weight)
def pick_7_13(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_7_9(code, weight)
    case False{}: look_10_13(code, weight)
def look_7_13(+code: U32, +weight: U32) -> U32: pick_7_13(U32.is_lt(code, 42), code, weight)
def pick_0_13(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_6(code, weight)
    case False{}: look_7_13(code, weight)
def look_0_13(+code: U32, +weight: U32) -> U32: pick_0_13(U32.is_lt(code, 39), code, weight)
def look_14_14(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 46), weight_of(weight, 277, 294, 311), 560)
def look_15_15(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 47), weight_of(weight, 285, 295, 305), 560)
def look_16_16(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 48), weight_of(weight, 610, 628, 647), 560)
def pick_15_16(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_15_15(code, weight)
    case False{}: look_16_16(code, weight)
def look_15_16(+code: U32, +weight: U32) -> U32: pick_15_16(U32.is_lt(code, 48), code, weight)
def pick_14_16(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_14_14(code, weight)
    case False{}: look_15_16(code, weight)
def look_14_16(+code: U32, +weight: U32) -> U32: pick_14_16(U32.is_lt(code, 47), code, weight)
def look_17_17(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 49), weight_of(weight, 444, 460, 476), 560)
def look_18_18(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 50), weight_of(weight, 584, 597, 610), 560)
def pick_17_18(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_17_17(code, weight)
    case False{}: look_18_18(code, weight)
def look_17_18(+code: U32, +weight: U32) -> U32: pick_17_18(U32.is_lt(code, 50), code, weight)
def look_19_19(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 51), weight_of(weight, 607, 622, 635), 560)
def look_20_20(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 52), weight_of(weight, 624, 639, 653), 560)
def pick_19_20(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_19_19(code, weight)
    case False{}: look_20_20(code, weight)
def look_19_20(+code: U32, +weight: U32) -> U32: pick_19_20(U32.is_lt(code, 52), code, weight)
def pick_17_20(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_17_18(code, weight)
    case False{}: look_19_20(code, weight)
def look_17_20(+code: U32, +weight: U32) -> U32: pick_17_20(U32.is_lt(code, 51), code, weight)
def pick_14_20(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_14_16(code, weight)
    case False{}: look_17_20(code, weight)
def look_14_20(+code: U32, +weight: U32) -> U32: pick_14_20(U32.is_lt(code, 49), code, weight)
def look_21_21(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 53), weight_of(weight, 599, 614, 629), 560)
def look_22_22(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 54), weight_of(weight, 617, 633, 648), 560)
def look_23_23(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 55), weight_of(weight, 569, 581, 593), 560)
def pick_22_23(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_22_22(code, weight)
    case False{}: look_23_23(code, weight)
def look_22_23(+code: U32, +weight: U32) -> U32: pick_22_23(U32.is_lt(code, 55), code, weight)
def pick_21_23(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_21_21(code, weight)
    case False{}: look_22_23(code, weight)
def look_21_23(+code: U32, +weight: U32) -> U32: pick_21_23(U32.is_lt(code, 54), code, weight)
def look_24_24(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 56), weight_of(weight, 619, 638, 656), 560)
def look_25_25(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 57), weight_of(weight, 617, 633, 648), 560)
def pick_24_25(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_24_24(code, weight)
    case False{}: look_25_25(code, weight)
def look_24_25(+code: U32, +weight: U32) -> U32: pick_24_25(U32.is_lt(code, 57), code, weight)
def look_26_26(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 58), weight_of(weight, 277, 294, 311), 560)
def look_27_27(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 59), weight_of(weight, 277, 294, 311), 560)
def pick_26_27(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_26_26(code, weight)
    case False{}: look_27_27(code, weight)
def look_26_27(+code: U32, +weight: U32) -> U32: pick_26_27(U32.is_lt(code, 59), code, weight)
def pick_24_27(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_24_25(code, weight)
    case False{}: look_26_27(code, weight)
def look_24_27(+code: U32, +weight: U32) -> U32: pick_24_27(U32.is_lt(code, 58), code, weight)
def pick_21_27(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_21_23(code, weight)
    case False{}: look_24_27(code, weight)
def look_21_27(+code: U32, +weight: U32) -> U32: pick_21_27(U32.is_lt(code, 56), code, weight)
def pick_14_27(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_14_20(code, weight)
    case False{}: look_21_27(code, weight)
def look_14_27(+code: U32, +weight: U32) -> U32: pick_14_27(U32.is_lt(code, 53), code, weight)
def pick_0_27(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_13(code, weight)
    case False{}: look_14_27(code, weight)
def look_0_27(+code: U32, +weight: U32) -> U32: pick_0_27(U32.is_lt(code, 46), code, weight)
def look_28_28(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 60), weight_of(weight, 610, 624, 638), 560)
def look_29_29(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 61), weight_of(weight, 610, 624, 638), 560)
def look_30_30(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 62), weight_of(weight, 610, 624, 638), 560)
def pick_29_30(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_29_29(code, weight)
    case False{}: look_30_30(code, weight)
def look_29_30(+code: U32, +weight: U32) -> U32: pick_29_30(U32.is_lt(code, 62), code, weight)
def pick_28_30(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_28_28(code, weight)
    case False{}: look_29_30(code, weight)
def look_28_30(+code: U32, +weight: U32) -> U32: pick_28_30(U32.is_lt(code, 61), code, weight)
def look_31_31(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 63), weight_of(weight, 493, 508, 523), 560)
def look_32_32(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 64), weight_of(weight, 898, 901, 904), 560)
def pick_31_32(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_31_31(code, weight)
    case False{}: look_32_32(code, weight)
def look_31_32(+code: U32, +weight: U32) -> U32: pick_31_32(U32.is_lt(code, 64), code, weight)
def look_33_33(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 65), weight_of(weight, 654, 674, 693), 560)
def look_34_34(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 66), weight_of(weight, 638, 650, 662), 560)
def pick_33_34(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_33_33(code, weight)
    case False{}: look_34_34(code, weight)
def look_33_34(+code: U32, +weight: U32) -> U32: pick_33_34(U32.is_lt(code, 66), code, weight)
def pick_31_34(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_31_32(code, weight)
    case False{}: look_33_34(code, weight)
def look_31_34(+code: U32, +weight: U32) -> U32: pick_31_34(U32.is_lt(code, 65), code, weight)
def pick_28_34(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_28_30(code, weight)
    case False{}: look_31_34(code, weight)
def look_28_34(+code: U32, +weight: U32) -> U32: pick_28_34(U32.is_lt(code, 63), code, weight)
def look_35_35(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 67), weight_of(weight, 696, 705, 713), 560)
def look_36_36(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 68), weight_of(weight, 707, 714, 721), 560)
def look_37_37(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 69), weight_of(weight, 576, 585, 594), 560)
def pick_36_37(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_36_36(code, weight)
    case False{}: look_37_37(code, weight)
def look_36_37(+code: U32, +weight: U32) -> U32: pick_36_37(U32.is_lt(code, 69), code, weight)
def pick_35_37(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_35_35(code, weight)
    case False{}: look_36_37(code, weight)
def look_35_37(+code: U32, +weight: U32) -> U32: pick_35_37(U32.is_lt(code, 68), code, weight)
def look_38_38(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 70), weight_of(weight, 553, 561, 569), 560)
def look_39_39(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 71), weight_of(weight, 727, 731, 736), 560)
def pick_38_39(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_38_38(code, weight)
    case False{}: look_39_39(code, weight)
def look_38_39(+code: U32, +weight: U32) -> U32: pick_38_39(U32.is_lt(code, 71), code, weight)
def look_40_40(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 72), weight_of(weight, 723, 736, 750), 560)
def look_41_41(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 73), weight_of(weight, 248, 265, 282), 560)
def pick_40_41(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_40_40(code, weight)
    case False{}: look_41_41(code, weight)
def look_40_41(+code: U32, +weight: U32) -> U32: pick_40_41(U32.is_lt(code, 73), code, weight)
def pick_38_41(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_38_39(code, weight)
    case False{}: look_40_41(code, weight)
def look_38_41(+code: U32, +weight: U32) -> U32: pick_38_41(U32.is_lt(code, 72), code, weight)
def pick_35_41(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_35_37(code, weight)
    case False{}: look_38_41(code, weight)
def look_35_41(+code: U32, +weight: U32) -> U32: pick_35_41(U32.is_lt(code, 70), code, weight)
def pick_28_41(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_28_34(code, weight)
    case False{}: look_35_41(code, weight)
def look_28_41(+code: U32, +weight: U32) -> U32: pick_28_41(U32.is_lt(code, 67), code, weight)
def look_42_42(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 74), weight_of(weight, 519, 540, 561), 560)
def look_43_43(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 75), weight_of(weight, 639, 656, 673), 560)
def look_44_44(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 76), weight_of(weight, 548, 557, 566), 560)
def pick_43_44(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_43_43(code, weight)
    case False{}: look_44_44(code, weight)
def look_43_44(+code: U32, +weight: U32) -> U32: pick_43_44(U32.is_lt(code, 76), code, weight)
def pick_42_44(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_42_42(code, weight)
    case False{}: look_43_44(code, weight)
def look_42_44(+code: U32, +weight: U32) -> U32: pick_42_44(U32.is_lt(code, 75), code, weight)
def look_45_45(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 77), weight_of(weight, 854, 865, 876), 560)
def look_46_46(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 78), weight_of(weight, 723, 731, 740), 560)
def pick_45_46(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_45_45(code, weight)
    case False{}: look_46_46(code, weight)
def look_45_46(+code: U32, +weight: U32) -> U32: pick_45_46(U32.is_lt(code, 78), code, weight)
def look_47_47(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 79), weight_of(weight, 752, 757, 762), 560)
def look_48_48(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 80), weight_of(weight, 616, 628, 641), 560)
def pick_47_48(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_47_47(code, weight)
    case False{}: look_48_48(code, weight)
def look_47_48(+code: U32, +weight: U32) -> U32: pick_47_48(U32.is_lt(code, 80), code, weight)
def pick_45_48(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_45_46(code, weight)
    case False{}: look_47_48(code, weight)
def look_45_48(+code: U32, +weight: U32) -> U32: pick_45_48(U32.is_lt(code, 79), code, weight)
def pick_42_48(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_42_44(code, weight)
    case False{}: look_45_48(code, weight)
def look_42_48(+code: U32, +weight: U32) -> U32: pick_42_48(U32.is_lt(code, 77), code, weight)
def look_49_49(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 81), weight_of(weight, 752, 757, 762), 560)
def look_50_50(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 82), weight_of(weight, 634, 647, 661), 560)
def look_51_51(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 83), weight_of(weight, 618, 630, 643), 560)
def pick_50_51(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_50_50(code, weight)
    case False{}: look_51_51(code, weight)
def look_50_51(+code: U32, +weight: U32) -> U32: pick_50_51(U32.is_lt(code, 83), code, weight)
def pick_49_51(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_49_49(code, weight)
    case False{}: look_50_51(code, weight)
def look_49_51(+code: U32, +weight: U32) -> U32: pick_49_51(U32.is_lt(code, 82), code, weight)
def look_52_52(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 84), weight_of(weight, 614, 623, 632), 560)
def look_53_53(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 85), weight_of(weight, 718, 726, 733), 560)
def pick_52_53(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_52_52(code, weight)
    case False{}: look_53_53(code, weight)
def look_52_53(+code: U32, +weight: U32) -> U32: pick_52_53(U32.is_lt(code, 85), code, weight)
def look_54_54(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 86), weight_of(weight, 654, 670, 686), 560)
def look_55_55(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 87), weight_of(weight, 948, 962, 976), 560)
def pick_54_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_54_54(code, weight)
    case False{}: look_55_55(code, weight)
def look_54_55(+code: U32, +weight: U32) -> U32: pick_54_55(U32.is_lt(code, 87), code, weight)
def pick_52_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_52_53(code, weight)
    case False{}: look_54_55(code, weight)
def look_52_55(+code: U32, +weight: U32) -> U32: pick_52_55(U32.is_lt(code, 86), code, weight)
def pick_49_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_49_51(code, weight)
    case False{}: look_52_55(code, weight)
def look_49_55(+code: U32, +weight: U32) -> U32: pick_49_55(U32.is_lt(code, 84), code, weight)
def pick_42_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_42_48(code, weight)
    case False{}: look_49_55(code, weight)
def look_42_55(+code: U32, +weight: U32) -> U32: pick_42_55(U32.is_lt(code, 81), code, weight)
def pick_28_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_28_41(code, weight)
    case False{}: look_42_55(code, weight)
def look_28_55(+code: U32, +weight: U32) -> U32: pick_28_55(U32.is_lt(code, 74), code, weight)
def pick_0_55(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_27(code, weight)
    case False{}: look_28_55(code, weight)
def look_0_55(+code: U32, +weight: U32) -> U32: pick_0_55(U32.is_lt(code, 60), code, weight)
def look_56_56(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 88), weight_of(weight, 659, 676, 693), 560)
def look_57_57(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 89), weight_of(weight, 636, 653, 671), 560)
def look_58_58(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 90), weight_of(weight, 642, 647, 651), 560)
def pick_57_58(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_57_57(code, weight)
    case False{}: look_58_58(code, weight)
def look_57_58(+code: U32, +weight: U32) -> U32: pick_57_58(U32.is_lt(code, 90), code, weight)
def pick_56_58(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_56_56(code, weight)
    case False{}: look_57_58(code, weight)
def look_56_58(+code: U32, +weight: U32) -> U32: pick_56_58(U32.is_lt(code, 89), code, weight)
def look_59_59(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 91), weight_of(weight, 362, 378, 394), 560)
def look_60_60(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 92), weight_of(weight, 285, 295, 305), 560)
def pick_59_60(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_59_59(code, weight)
    case False{}: look_60_60(code, weight)
def look_59_60(+code: U32, +weight: U32) -> U32: pick_59_60(U32.is_lt(code, 92), code, weight)
def look_61_61(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 93), weight_of(weight, 362, 378, 394), 560)
def look_62_62(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 94), weight_of(weight, 610, 624, 638), 560)
def pick_61_62(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_61_61(code, weight)
    case False{}: look_62_62(code, weight)
def look_61_62(+code: U32, +weight: U32) -> U32: pick_61_62(U32.is_lt(code, 94), code, weight)
def pick_59_62(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_59_60(code, weight)
    case False{}: look_61_62(code, weight)
def look_59_62(+code: U32, +weight: U32) -> U32: pick_59_62(U32.is_lt(code, 93), code, weight)
def pick_56_62(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_56_58(code, weight)
    case False{}: look_59_62(code, weight)
def look_56_62(+code: U32, +weight: U32) -> U32: pick_56_62(U32.is_lt(code, 91), code, weight)
def look_63_63(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 95), weight_of(weight, 525, 540, 555), 560)
def look_64_64(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 96), weight_of(weight, 480, 480, 480), 560)
def look_65_65(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 97), weight_of(weight, 532, 545, 558), 560)
def pick_64_65(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_64_64(code, weight)
    case False{}: look_65_65(code, weight)
def look_64_65(+code: U32, +weight: U32) -> U32: pick_64_65(U32.is_lt(code, 97), code, weight)
def pick_63_65(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_63_63(code, weight)
    case False{}: look_64_65(code, weight)
def look_63_65(+code: U32, +weight: U32) -> U32: pick_63_65(U32.is_lt(code, 96), code, weight)
def look_66_66(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 98), weight_of(weight, 595, 607, 620), 560)
def look_67_67(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 99), weight_of(weight, 540, 549, 559), 560)
def pick_66_67(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_66_66(code, weight)
    case False{}: look_67_67(code, weight)
def look_66_67(+code: U32, +weight: U32) -> U32: pick_66_67(U32.is_lt(code, 99), code, weight)
def look_68_68(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 100), weight_of(weight, 595, 607, 620), 560)
def look_69_69(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 101), weight_of(weight, 552, 562, 571), 560)
def pick_68_69(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_68_68(code, weight)
    case False{}: look_69_69(code, weight)
def look_68_69(+code: U32, +weight: U32) -> U32: pick_68_69(U32.is_lt(code, 101), code, weight)
def pick_66_69(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_66_67(code, weight)
    case False{}: look_68_69(code, weight)
def look_66_69(+code: U32, +weight: U32) -> U32: pick_66_69(U32.is_lt(code, 100), code, weight)
def pick_63_69(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_63_65(code, weight)
    case False{}: look_66_69(code, weight)
def look_63_69(+code: U32, +weight: U32) -> U32: pick_63_69(U32.is_lt(code, 98), code, weight)
def pick_56_69(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_56_62(code, weight)
    case False{}: look_63_69(code, weight)
def look_56_69(+code: U32, +weight: U32) -> U32: pick_56_69(U32.is_lt(code, 95), code, weight)
def look_70_70(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 102), weight_of(weight, 342, 360, 376), 560)
def look_71_71(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 103), weight_of(weight, 590, 602, 614), 560)
def look_72_72(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 104), weight_of(weight, 569, 583, 598), 560)
def pick_71_72(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_71_71(code, weight)
    case False{}: look_72_72(code, weight)
def look_71_72(+code: U32, +weight: U32) -> U32: pick_71_72(U32.is_lt(code, 104), code, weight)
def pick_70_72(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_70_70(code, weight)
    case False{}: look_71_72(code, weight)
def look_70_72(+code: U32, +weight: U32) -> U32: pick_70_72(U32.is_lt(code, 103), code, weight)
def look_73_73(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 105), weight_of(weight, 228, 241, 254), 560)
def look_74_74(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 106), weight_of(weight, 227, 241, 254), 560)
def pick_73_74(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_73_73(code, weight)
    case False{}: look_74_74(code, weight)
def look_73_74(+code: U32, +weight: U32) -> U32: pick_73_74(U32.is_lt(code, 106), code, weight)
def look_75_75(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 107), weight_of(weight, 523, 543, 563), 560)
def look_76_76(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 108), weight_of(weight, 233, 248, 261), 560)
def pick_75_76(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_75_75(code, weight)
    case False{}: look_76_76(code, weight)
def look_75_76(+code: U32, +weight: U32) -> U32: pick_75_76(U32.is_lt(code, 108), code, weight)
def pick_73_76(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_73_74(code, weight)
    case False{}: look_75_76(code, weight)
def look_73_76(+code: U32, +weight: U32) -> U32: pick_73_76(U32.is_lt(code, 107), code, weight)
def pick_70_76(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_70_72(code, weight)
    case False{}: look_73_76(code, weight)
def look_70_76(+code: U32, +weight: U32) -> U32: pick_70_76(U32.is_lt(code, 105), code, weight)
def look_77_77(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 109), weight_of(weight, 851, 871, 892), 560)
def look_78_78(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 110), weight_of(weight, 564, 579, 593), 560)
def look_79_79(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 111), weight_of(weight, 571, 581, 590), 560)
def pick_78_79(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_78_78(code, weight)
    case False{}: look_79_79(code, weight)
def look_78_79(+code: U32, +weight: U32) -> U32: pick_78_79(U32.is_lt(code, 111), code, weight)
def pick_77_79(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_77_77(code, weight)
    case False{}: look_78_79(code, weight)
def look_77_79(+code: U32, +weight: U32) -> U32: pick_77_79(U32.is_lt(code, 110), code, weight)
def look_80_80(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 112), weight_of(weight, 591, 603, 615), 560)
def look_81_81(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 113), weight_of(weight, 590, 603, 615), 560)
def pick_80_81(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_80_80(code, weight)
    case False{}: look_81_81(code, weight)
def look_80_81(+code: U32, +weight: U32) -> U32: pick_80_81(U32.is_lt(code, 113), code, weight)
def look_82_82(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 114), weight_of(weight, 371, 387, 404), 560)
def look_83_83(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 115), weight_of(weight, 494, 508, 523), 560)
def pick_82_83(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_82_82(code, weight)
    case False{}: look_83_83(code, weight)
def look_82_83(+code: U32, +weight: U32) -> U32: pick_82_83(U32.is_lt(code, 115), code, weight)
def pick_80_83(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_80_81(code, weight)
    case False{}: look_82_83(code, weight)
def look_80_83(+code: U32, +weight: U32) -> U32: pick_80_83(U32.is_lt(code, 114), code, weight)
def pick_77_83(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_77_79(code, weight)
    case False{}: look_80_83(code, weight)
def look_77_83(+code: U32, +weight: U32) -> U32: pick_77_83(U32.is_lt(code, 112), code, weight)
def pick_70_83(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_70_76(code, weight)
    case False{}: look_77_83(code, weight)
def look_70_83(+code: U32, +weight: U32) -> U32: pick_70_83(U32.is_lt(code, 109), code, weight)
def pick_56_83(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_56_69(code, weight)
    case False{}: look_70_83(code, weight)
def look_56_83(+code: U32, +weight: U32) -> U32: pick_56_83(U32.is_lt(code, 102), code, weight)
def look_84_84(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 116), weight_of(weight, 344, 362, 380), 560)
def look_85_85(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 117), weight_of(weight, 564, 579, 593), 560)
def look_86_86(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 118), weight_of(weight, 522, 536, 550), 560)
def pick_85_86(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_85_85(code, weight)
    case False{}: look_86_86(code, weight)
def look_85_86(+code: U32, +weight: U32) -> U32: pick_85_86(U32.is_lt(code, 118), code, weight)
def pick_84_86(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_84_84(code, weight)
    case False{}: look_85_86(code, weight)
def look_84_86(+code: U32, +weight: U32) -> U32: pick_84_86(U32.is_lt(code, 117), code, weight)
def look_87_87(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 119), weight_of(weight, 755, 779, 803), 560)
def look_88_88(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 120), weight_of(weight, 505, 523, 542), 560)
def pick_87_88(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_87_87(code, weight)
    case False{}: look_88_88(code, weight)
def look_87_88(+code: U32, +weight: U32) -> U32: pick_87_88(U32.is_lt(code, 120), code, weight)
def look_89_89(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 121), weight_of(weight, 523, 542, 560), 560)
def look_90_90(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 122), weight_of(weight, 520, 529, 538), 560)
def pick_89_90(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_89_89(code, weight)
    case False{}: look_90_90(code, weight)
def look_89_90(+code: U32, +weight: U32) -> U32: pick_89_90(U32.is_lt(code, 122), code, weight)
def pick_87_90(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_87_88(code, weight)
    case False{}: look_89_90(code, weight)
def look_87_90(+code: U32, +weight: U32) -> U32: pick_87_90(U32.is_lt(code, 121), code, weight)
def pick_84_90(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_84_86(code, weight)
    case False{}: look_87_90(code, weight)
def look_84_90(+code: U32, +weight: U32) -> U32: pick_84_90(U32.is_lt(code, 119), code, weight)
def look_91_91(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 123), weight_of(weight, 362, 378, 394), 560)
def look_92_92(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 124), weight_of(weight, 239, 253, 266), 560)
def look_93_93(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 125), weight_of(weight, 362, 378, 394), 560)
def pick_92_93(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_92_92(code, weight)
    case False{}: look_93_93(code, weight)
def look_92_93(+code: U32, +weight: U32) -> U32: pick_92_93(U32.is_lt(code, 125), code, weight)
def pick_91_93(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_91_91(code, weight)
    case False{}: look_92_93(code, weight)
def look_91_93(+code: U32, +weight: U32) -> U32: pick_91_93(U32.is_lt(code, 124), code, weight)
def look_94_94(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 126), weight_of(weight, 610, 624, 638), 560)
def look_95_95(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 161), weight_of(weight, 292, 307, 322), 560)
def pick_94_95(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_94_94(code, weight)
    case False{}: look_95_95(code, weight)
def look_94_95(+code: U32, +weight: U32) -> U32: pick_94_95(U32.is_lt(code, 161), code, weight)
def look_96_96(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 183), weight_of(weight, 277, 294, 311), 560)
def look_97_97(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 191), weight_of(weight, 493, 508, 523), 560)
def pick_96_97(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_96_96(code, weight)
    case False{}: look_97_97(code, weight)
def look_96_97(+code: U32, +weight: U32) -> U32: pick_96_97(U32.is_lt(code, 191), code, weight)
def pick_94_97(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_94_95(code, weight)
    case False{}: look_96_97(code, weight)
def look_94_97(+code: U32, +weight: U32) -> U32: pick_94_97(U32.is_lt(code, 183), code, weight)
def pick_91_97(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_91_93(code, weight)
    case False{}: look_94_97(code, weight)
def look_91_97(+code: U32, +weight: U32) -> U32: pick_91_97(U32.is_lt(code, 126), code, weight)
def pick_84_97(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_84_90(code, weight)
    case False{}: look_91_97(code, weight)
def look_84_97(+code: U32, +weight: U32) -> U32: pick_84_97(U32.is_lt(code, 123), code, weight)
def look_98_98(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 193), weight_of(weight, 654, 674, 693), 560)
def look_99_99(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 201), weight_of(weight, 576, 585, 594), 560)
def look_100_100(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 205), weight_of(weight, 248, 265, 282), 560)
def pick_99_100(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_99_99(code, weight)
    case False{}: look_100_100(code, weight)
def look_99_100(+code: U32, +weight: U32) -> U32: pick_99_100(U32.is_lt(code, 205), code, weight)
def pick_98_100(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_98_98(code, weight)
    case False{}: look_99_100(code, weight)
def look_98_100(+code: U32, +weight: U32) -> U32: pick_98_100(U32.is_lt(code, 201), code, weight)
def look_101_101(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 209), weight_of(weight, 723, 731, 740), 560)
def look_102_102(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 211), weight_of(weight, 752, 757, 762), 560)
def pick_101_102(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_101_101(code, weight)
    case False{}: look_102_102(code, weight)
def look_101_102(+code: U32, +weight: U32) -> U32: pick_101_102(U32.is_lt(code, 211), code, weight)
def look_103_103(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 218), weight_of(weight, 718, 726, 733), 560)
def look_104_104(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 225), weight_of(weight, 532, 545, 558), 560)
def pick_103_104(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_103_103(code, weight)
    case False{}: look_104_104(code, weight)
def look_103_104(+code: U32, +weight: U32) -> U32: pick_103_104(U32.is_lt(code, 225), code, weight)
def pick_101_104(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_101_102(code, weight)
    case False{}: look_103_104(code, weight)
def look_101_104(+code: U32, +weight: U32) -> U32: pick_101_104(U32.is_lt(code, 218), code, weight)
def pick_98_104(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_98_100(code, weight)
    case False{}: look_101_104(code, weight)
def look_98_104(+code: U32, +weight: U32) -> U32: pick_98_104(U32.is_lt(code, 209), code, weight)
def look_105_105(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 233), weight_of(weight, 552, 562, 571), 560)
def look_106_106(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 237), weight_of(weight, 228, 241, 254), 560)
def pick_105_106(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_105_105(code, weight)
    case False{}: look_106_106(code, weight)
def look_105_106(+code: U32, +weight: U32) -> U32: pick_105_106(U32.is_lt(code, 237), code, weight)
def look_107_107(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 241), weight_of(weight, 564, 579, 593), 560)
def look_108_108(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 243), weight_of(weight, 571, 581, 590), 560)
def pick_107_108(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_107_107(code, weight)
    case False{}: look_108_108(code, weight)
def look_107_108(+code: U32, +weight: U32) -> U32: pick_107_108(U32.is_lt(code, 243), code, weight)
def pick_105_108(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_105_106(code, weight)
    case False{}: look_107_108(code, weight)
def look_105_108(+code: U32, +weight: U32) -> U32: pick_105_108(U32.is_lt(code, 241), code, weight)
def look_109_109(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 250), weight_of(weight, 564, 579, 593), 560)
def look_110_110(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 252), weight_of(weight, 564, 579, 593), 560)
def pick_109_110(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_109_109(code, weight)
    case False{}: look_110_110(code, weight)
def look_109_110(+code: U32, +weight: U32) -> U32: pick_109_110(U32.is_lt(code, 252), code, weight)
def look_111_111(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 8212), weight_of(weight, 867, 878, 889), 560)
def look_112_112(+code: U32, +weight: U32) -> U32:
  Bool.pick(U32, U32.is_eq(code, 8230), weight_of(weight, 785, 835, 885), 560)
def pick_111_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_111_111(code, weight)
    case False{}: look_112_112(code, weight)
def look_111_112(+code: U32, +weight: U32) -> U32: pick_111_112(U32.is_lt(code, 8230), code, weight)
def pick_109_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_109_110(code, weight)
    case False{}: look_111_112(code, weight)
def look_109_112(+code: U32, +weight: U32) -> U32: pick_109_112(U32.is_lt(code, 8212), code, weight)
def pick_105_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_105_108(code, weight)
    case False{}: look_109_112(code, weight)
def look_105_112(+code: U32, +weight: U32) -> U32: pick_105_112(U32.is_lt(code, 250), code, weight)
def pick_98_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_98_104(code, weight)
    case False{}: look_105_112(code, weight)
def look_98_112(+code: U32, +weight: U32) -> U32: pick_98_112(U32.is_lt(code, 233), code, weight)
def pick_84_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_84_97(code, weight)
    case False{}: look_98_112(code, weight)
def look_84_112(+code: U32, +weight: U32) -> U32: pick_84_112(U32.is_lt(code, 193), code, weight)
def pick_56_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_56_83(code, weight)
    case False{}: look_84_112(code, weight)
def look_56_112(+code: U32, +weight: U32) -> U32: pick_56_112(U32.is_lt(code, 116), code, weight)
def pick_0_112(hit: Bool, +code: U32, +weight: U32) -> U32:
  match hit:
    case True{}: look_0_55(code, weight)
    case False{}: look_56_112(code, weight)
def look_0_112(+code: U32, +weight: U32) -> U32: pick_0_112(U32.is_lt(code, 88), code, weight)
def advance(c: Char, +weight: U32) -> U32:
  match c:
    case Chr{code}: look_0_112(code, weight)
# Sum of advances in thousandths of an em at 16px.
def ems(s: String, +weight: U32) -> U32:
  match s:
    case SNil{}: 0
    case SCon{c, rest}: U32.add(advance(c, weight), ems(rest, weight))
# Tracking per size, in thousandths, relative to the 16px measurements.
def tracking(+size: U32) -> U32:
  Bool.pick(U32, U32.is_le(size, 11), 1049, Bool.pick(U32, U32.is_eq(size, 12), 1037, Bool.pick(U32, U32.is_eq(size, 13), 1025,
  Bool.pick(U32, U32.is_eq(size, 14), 1015, Bool.pick(U32, U32.is_eq(size, 15), 1004, Bool.pick(U32, U32.is_eq(size, 16), 997,
  Bool.pick(U32, U32.is_eq(size, 17), 985, Bool.pick(U32, U32.is_eq(size, 18), 981, Bool.pick(U32, U32.is_eq(size, 19), 978, 960)))))))))
def weight_in(t: P.TextType) -> U32:
  match t:
    case P.TextType{name, size, weight}: weight
# Width in px of a run whose advances sum to `e` thousandths of an em, set
# in `text_type`, rounded up, plus 1px of room.
def width_ems(+e: U32, text_type: P.TextType) -> U32:
  match text_type:
    case P.TextType{name, +size, weight}:
      U32.add(U32.div(U32.add(U32.mul(U32.div(U32.mul(e, size), 1000), tracking(size)), 999), 1000), 1)
def width(s: String, +text_type: P.TextType) -> U32: width_ems(ems(s, weight_in(text_type)), text_type)

# Greedy word wrap at `max` px: the same rule the browser applies. The state
# is the open line, its advance sum, and the finished lines (latest first);
# each word is measured once and either joins the open line or starts a new
# one. Both candidates are plain values, so the recursion runs once a word.
type Wrap is Data:
  Wrap{line: String, line_ems: U32, done: List<&2, String>}
def step(s: Wrap, +word: String, +max: U32, +text_type: P.TextType) -> Wrap:
  match s:
    case Wrap{+line, +line_ems, +done}:
      +w = ems(word, weight_in(text_type))
      +joined = U32.add(U32.add(line_ems, advance(Chr{32}, weight_in(text_type))), w)
      Bool.pick(Wrap, String.is_empty(line), Wrap{word, w, done},
        Bool.pick(Wrap, U32.is_le(width_ems(joined, text_type), max), Wrap{line ++ " " ++ word, joined, done}, Wrap{word, w, Con{line, done}}))
def wrap(words: List<&2, String>, s: Wrap, +max: U32, +text_type: P.TextType) -> Wrap:
  match words:
    case Nil{}: s
    case Con{word, rest}: wrap(rest, step(s, word, max, text_type), max, text_type)
def reverse(xs: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case Con{x, rest}: reverse(rest, Con{x, acc})
def finish(s: Wrap) -> List<&2, String>:
  match s:
    case Wrap{+line, e, +done}: reverse(Bool.pick(List<&2, String>, String.is_empty(line), done, Con{line, done}), [])
def lines(s: String, +max: U32, +text_type: P.TextType) -> List<&2, String>:
  finish(wrap(String.split(s, Chr{32}), Wrap{"", 0, []}, max, text_type))
def widest(xs: List<&2, String>, +text_type: P.TextType) -> U32:
  match xs:
    case Nil{}: 0
    case Con{x, rest}: U32.max(width(x, text_type), widest(rest, text_type))

# Truncate rule: the longest prefix that fits `max` px with the ellipsis,
# measured incrementally.
def ellipsis() -> String: "…"
def choose_text(condition: Bool, yes: Unit -> String, no: Unit -> String) -> String:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})
def take_fit(s: String, +max: U32, +text_type: P.TextType, +prefix: String, +prefix_ems: U32, +ell: U32) -> String:
  match s:
    case SNil{}: prefix
    case SCon{+c, rest}:
      +next_ems = U32.add(prefix_ems, advance(c, weight_in(text_type)))
      choose_text(U32.is_le(width_ems(U32.add(next_ems, ell), text_type), max), u => take_fit(rest, max, text_type, prefix ++ SCon{c, SNil{}}, next_ems, ell), u => prefix)
def truncate(+s: String, +max: U32, +text_type: P.TextType) -> String:
  choose_text(U32.is_le(width(s, text_type), max), u => s, u => take_fit(s, max, text_type, "", 0, ems(ellipsis(), weight_in(text_type))) ++ ellipsis())
# The longest word: the minimum width of wrapped text.
def longest_word(+s: String, +text_type: P.TextType) -> U32:
  widest(String.split(s, Chr{32}), text_type)
# Readability: a body line holds about 70 characters. The readable width is
# the measured width of a 70-character generic sample.
def readable_sample() -> String: "A readable interface uses clear words, useful spacing and simple labels."
