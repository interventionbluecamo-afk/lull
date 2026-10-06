# Teal keying-artifact audit — App/Resources/Assets.xcassets

Generated 2026-06-11 | key #3E6877 (r62 g104 b119) | report-only, no files modified.

Scanned **187 PNGs** (176 audited, 11 skipped/legit-blue by name rule: contains night/moon/cloud/star).

## Metric definitions

- **edge-fringe (spec)**: alpha>40 px within 3px (Chebyshev) of any alpha<40 px, with b>r+12 and b>70; count and % of that edge band.
- **interior teal (spec)**: alpha>200, b>r+25, b>90, HSV sat>0.15. CAUTION: also fires on legitimately blue art (blueberries, bluebird, blue sweater, sky) — see `blue frac` and `pocket px` to disambiguate.
- **pocket px (added)**: opaque px matching the keyed-out background color — exact key dist<18, plus a per-image background estimate (mean RGB under alpha==0, used only for warm-content images), eroded 2x so only flat blobs survive. This is the high-precision 'enclosed teal pocket' detector; validated visually (shelfroom-shelf slab, feed-cup + feed-basket handle holes, shelf-hum wedge, butterfly shadow).
- **semi-a teal (added)**: 40<alpha<=200 px anywhere with b>r+12, b>70 — teal-tinted soft shadows/wisps (case c).
- **blue frac**: share of opaque px that are blue-dominant; >=0.30 means content is blue and the spec metrics are unreliable for it.

## Verdict rules

- **NEEDS FIX**: pocket>=500, or (warm content and fringe>=1500px at >=15%), or (warm and fringe>=300px at >=30%).
- **MINOR FRINGE**: pocket>=25, or (warm and fringe>=300px or >=8%), or (blue content and fringe>=2000px at >=50% — cannot be auto-cleared, needs an eyeball).
- **CLEAN**: everything else.

## Totals

- Audited 169 imagesets + 18 app-icon PNGs: **NEEDS FIX 44** | **MINOR FRINGE 70** | CLEAN 62 | skipped/legit-blue 11
- Totals over audited rows: fringe px 234355, interior-teal px 1092445, pocket px 308815, semi-alpha teal px 175685

## Ranked results — worst first

| imageset | size | edge-fringe px | fringe % | edge band | interior teal px | pocket px | semi-a teal | blue frac | fringe avg | bg est | verdict | note |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| shelfroom-shelf | 1279x610 | 1258 | 10.2% | 12337 | 236698 | 230077 | 486 | 0.40 | #436771 | #3d798c | NEEDS FIX | flat key-color pocket ~230077px; blue content: fringe/interior metrics confounded, eyeball |
| shelf-hum | 1088x676 | 3300 | 25.6% | 12911 | 54168 | 11143 | 2745 | 0.12 | #405f6a | #31607a | NEEDS FIX | flat key-color pocket ~11143px |
| bubbles-pot | 1033x729 | 1324 | 11.5% | 11555 | 230 | 7653 | 3110 | 0.02 | #365663 | #17415c | NEEDS FIX | flat key-color pocket ~7653px; teal-tinted soft alpha (shadow/wisp) |
| stack-capstone | 583x407 | 836 | 13.8% | 6041 | 378 | 7565 | 4062 | 0.06 | #1f4556 | #163a4f | NEEDS FIX | flat key-color pocket ~7565px; teal-tinted soft alpha (shadow/wisp) |
| feed-cup | 902x781 | 708 | 7.0% | 10104 | 8016 | 7184 | 257 | 0.02 | #435f65 | #265971 | NEEDS FIX | flat key-color pocket ~7184px |
| meadow-butterfly | 826x651 | 6254 | 42.1% | 14864 | 8155 | 5889 | 9424 | 0.04 | #2c5560 | #144964 | NEEDS FIX | flat key-color pocket ~5889px; teal-tinted soft alpha (shadow/wisp) |
| meadow-snail-top | 879x640 | 2308 | 18.6% | 12436 | 1336 | 5479 | 7050 | 0.03 | #546b6d | #3b5859 | NEEDS FIX | flat key-color pocket ~5479px; teal-tinted soft alpha (shadow/wisp) |
| window-cat-asleep | 1032x731 | 3641 | 33.2% | 10973 | 1940 | 5184 | 5622 | 0.02 | #48625d | #587c79 | NEEDS FIX | flat key-color pocket ~5184px; teal-tinted soft alpha (shadow/wisp) |
| dropdots-tray | 1555x344 | 3229 | 27.9% | 11594 | 171 | 5090 | 3668 | 0.02 | #204453 | #173647 | NEEDS FIX | flat key-color pocket ~5090px; teal-tinted soft alpha (shadow/wisp) |
| meadow-dandelion | 870x1022 | 22113 | 72.1% | 30682 | 11970 | 0 | 4248 | 0.04 | #70868d | #375a6b | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key; teal-tinted soft alpha (shadow/wisp) |
| feed-basket | 1254x980 | 2674 | 22.7% | 11762 | 6904 | 4170 | 1028 | 0.02 | #38a5a8 | #0d9cb5 | NEEDS FIX | flat key-color pocket ~4170px |
| dropdots-tab | 1034x488 | 1181 | 8.3% | 14279 | 91 | 4342 | 4258 | 0.02 | #254856 | #142e40 | NEEDS FIX | flat key-color pocket ~4342px; teal-tinted soft alpha (shadow/wisp) |
| dropdots-token-leaf | 331x324 | 752 | 18.5% | 4055 | 120 | 2953 | 2570 | 0.06 | #214758 | #13364b | NEEDS FIX | flat key-color pocket ~2953px |
| dropdots-token-berry | 338x344 | 717 | 17.2% | 4166 | 100 | 2075 | 2474 | 0.05 | #164458 | #123245 | NEEDS FIX | flat key-color pocket ~2075px |
| shelf-meadow | 936x600 | 2885 | 15.1% | 19103 | 531 | 1716 | 2144 | 0.02 | #496166 | #27485a | NEEDS FIX | flat key-color pocket ~1716px |
| shelf-plant | 826x983 | 117 | 0.7% | 16523 | 2104 | 1781 | 88 | 0.01 | #4b635d | #305f6e | NEEDS FIX | flat key-color pocket ~1781px |
| king-body | 537x402 | 481 | 8.1% | 5974 | 2943 | 1246 | 117 | 0.20 | #5b6f75 | #23516a | NEEDS FIX | flat key-color pocket ~1246px |
| queen-body | 537x402 | 481 | 8.1% | 5974 | 2943 | 1246 | 117 | 0.20 | #5b6f75 | #23516a | NEEDS FIX | flat key-color pocket ~1246px |
| meadow-rosette | 834x913 | 6615 | 36.0% | 18377 | 2480 | 0 | 1354 | 0.01 | #5c7177 | #2f566b | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| window-trees-day | 1370x643 | 1176 | 7.7% | 15253 | 832 | 618 | 2050 | 0.02 | #3b5e5a | #2e5e66 | NEEDS FIX | flat key-color pocket ~618px |
| dropdots-board | 882x1347 | 3259 | 23.8% | 13717 | 8570 | 359 | 2778 | 0.01 | #17465d | #0e3c53 | NEEDS FIX | flat key-color pocket ~359px |
| mouse-body | 699x401 | 1850 | 17.7% | 10438 | 444 | 475 | 3370 | 0.02 | #436067 | #174658 | NEEDS FIX | flat key-color pocket ~475px; teal-tinted soft alpha (shadow/wisp) |
| mouse2-body | 699x401 | 1850 | 17.7% | 10438 | 444 | 475 | 3370 | 0.02 | #436067 | #174658 | NEEDS FIX | flat key-color pocket ~475px; teal-tinted soft alpha (shadow/wisp) |
| shelf-feed | 703x613 | 1885 | 18.3% | 10305 | 1600 | 444 | 535 | 0.01 | #4c6b72 | #295a76 | NEEDS FIX | flat key-color pocket ~444px |
| bunny-head | 466x568 | 3812 | 43.1% | 8837 | 2474 | 4 | 618 | 0.02 | #5b7680 | #204962 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| bunny2-head | 466x568 | 3812 | 43.1% | 8837 | 2474 | 4 | 618 | 0.02 | #5b7680 | #204962 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| robot-legs | 450x246 | 2124 | 37.0% | 5743 | 1806 | 273 | 2007 | 0.06 | #1f4a5c | #0c557c | NEEDS FIX | flat key-color pocket ~273px |
| robot-body | 780x367 | 3734 | 33.5% | 11134 | 1914 | 47 | 6042 | 0.01 | #1d495d | #0e4f73 | NEEDS FIX | flat key-color pocket ~47px; teal-tinted soft alpha (shadow/wisp) |
| shelf-sleepybox | 629x669 | 1825 | 22.5% | 8119 | 13743 | 288 | 1336 | 0.04 | #1a4e65 | #1e5469 | NEEDS FIX | flat key-color pocket ~288px |
| king-legs | 328x150 | 1610 | 38.0% | 4242 | 1413 | 220 | 376 | 0.15 | #2a485a | #245772 | NEEDS FIX | flat key-color pocket ~220px |
| queen-legs | 328x150 | 1610 | 38.0% | 4242 | 1413 | 220 | 376 | 0.15 | #2a485a | #245772 | NEEDS FIX | flat key-color pocket ~220px |
| sleepybox-plant | 799x1078 | 2210 | 15.2% | 14542 | 1876 | 271 | 512 | 0.00 | #577a80 | #2b6986 | NEEDS FIX | flat key-color pocket ~271px |
| shelf-bubbles | 692x1032 | 3380 | 26.5% | 12753 | 36145 | 0 | 665 | 0.11 | #688586 | #225269 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| feed-egg | 1254x1101 | 3111 | 31.7% | 9826 | 1361 | 0 | 1477 | 0.00 | #4da2a9 | #269ca9 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| mouse-head | 593x416 | 2255 | 28.6% | 7882 | 916 | 47 | 2133 | 0.01 | #516f76 | #164457 | NEEDS FIX | flat key-color pocket ~47px |
| mouse2-head | 593x416 | 2255 | 28.6% | 7882 | 916 | 47 | 2133 | 0.01 | #516f76 | #164457 | NEEDS FIX | flat key-color pocket ~47px |
| window-sun | 976x970 | 3921 | 18.9% | 20799 | 1242 | 0 | 632 | 0.01 | #526e6d | #245e7c | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| robot-head | 584x514 | 2129 | 29.3% | 7268 | 1082 | 26 | 3197 | 0.01 | #255165 | #15547a | NEEDS FIX | flat key-color pocket ~26px; teal-tinted soft alpha (shadow/wisp) |
| feed-counter | 2172x501 | 2928 | 20.0% | 14671 | 2250 | 0 | 573 | 0.00 | #49a090 | #30ad9c | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| feed-apple | 1254x1051 | 2508 | 20.6% | 12166 | 986 | 0 | 1345 | 0.00 | #3dabab | #2ba5a6 | NEEDS FIX |  |
| feed-carrot | 1254x1254 | 2212 | 20.6% | 10749 | 1241 | 0 | 800 | 0.00 | #46b3a9 | #22b2c0 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| feed-pedestal | 1211x944 | 1866 | 16.8% | 11131 | 933 | 0 | 658 | 0.00 | #5da49b | #4bb9b3 | NEEDS FIX |  |
| feed-banana | 1067x813 | 1850 | 16.0% | 11592 | 1206 | 0 | 486 | 0.00 | #3e9a8b | #068792 | NEEDS FIX | interior px are blue/teal art or tinted shading, not flat key |
| shelf-blanket | 1035x902 | 1726 | 15.2% | 11390 | 178 | 0 | 1463 | 0.00 | #668086 | #2a5f74 | NEEDS FIX |  |
| songbird-head | 497x460 | 25765 | 96.7% | 26651 | 111891 | 0 | 28170 | 0.87 | #33528d | #2b4a69 | MINOR FRINGE | blue content: fringe/interior metrics confounded, eyeball |
| songbird-body | 654x370 | 21333 | 94.2% | 22656 | 66118 | 0 | 17193 | 0.45 | #3a5486 | #315374 | MINOR FRINGE | blue content: fringe/interior metrics confounded, eyeball |
| feed-berry | 909x795 | 9195 | 77.7% | 11828 | 364115 | 116 | 731 | 0.85 | #73759b | #36627c | MINOR FRINGE | flat key-color pocket ~116px; blue content: fringe/interior metrics confounded, eyeball |
| bunny-body | 527x301 | 1496 | 29.0% | 5159 | 879 | 0 | 354 | 0.01 | #5a7681 | #29546d | MINOR FRINGE |  |
| bunny2-body | 527x301 | 1496 | 29.0% | 5159 | 879 | 0 | 354 | 0.01 | #5a7681 | #29546d | MINOR FRINGE |  |
| shelf-window | 883x1077 | 1190 | 10.2% | 11660 | 328 | 67 | 465 | 0.22 | #52686c | #284f62 | MINOR FRINGE | flat key-color pocket ~67px |
| lion-head | 567x516 | 1493 | 20.0% | 7478 | 439 | 0 | 504 | 0.00 | #4f6b6b | #264654 | MINOR FRINGE |  |
| feed-bubble | 1073x904 | 1737 | 13.2% | 13114 | 744 | 0 | 631 | 0.00 | #54757f | #305e74 | MINOR FRINGE |  |
| sleepybox-triangle | 898x806 | 1552 | 14.7% | 10537 | 100 | 0 | 1307 | 0.00 | #175b8b | #235466 | MINOR FRINGE |  |
| window-dial-needle | 428x1074 | 1341 | 12.0% | 11167 | 320 | 0 | 796 | 0.00 | #2f8184 | #2a8d97 | MINOR FRINGE |  |
| mouse-legs | 350x249 | 970 | 13.9% | 6973 | 200 | 8 | 3005 | 0.01 | #3e5d65 | #0e3848 | MINOR FRINGE | teal-tinted soft alpha (shadow/wisp) |
| mouse2-legs | 350x249 | 970 | 13.9% | 6973 | 200 | 8 | 3005 | 0.01 | #3e5d65 | #0e3848 | MINOR FRINGE | teal-tinted soft alpha (shadow/wisp) |
| dog-head | 573x518 | 1046 | 15.1% | 6944 | 386 | 0 | 264 | 0.00 | #5b7076 | #1c4d67 | MINOR FRINGE |  |
| sleepybox-body | 865x1070 | 776 | 6.4% | 12104 | 15835 | 4 | 5353 | 0.02 | #244377 | #2c6a7b | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key; teal-tinted soft alpha (shadow/wisp) |
| zebra-head | 450x475 | 982 | 14.1% | 6959 | 353 | 0 | 247 | 0.00 | #5f767e | #234c62 | MINOR FRINGE |  |
| feed-cast-knithat-1 | 226x446 | 562 | 9.3% | 6019 | 16284 | 0 | 233 | 0.26 | #768892 | - | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key |
| wren-parts-sheet | 572x1026 | 1418 | 9.3% | 15220 | 33 | 0 | 1032 | 0.00 | #236c85 | #2a5f77 | MINOR FRINGE |  |
| feed-cast-knithat-2 | 224x431 | 545 | 9.0% | 6045 | 16270 | 0 | 220 | 0.27 | #738690 | - | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key |
| feed-cast-knithat-5 | 223x439 | 542 | 9.1% | 5973 | 16071 | 0 | 225 | 0.27 | #798a94 | - | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key |
| feed-cast-knithat-3 | 222x439 | 534 | 9.0% | 5942 | 16046 | 0 | 212 | 0.27 | #758791 | - | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key |
| shelf-mixup | 974x1031 | 1243 | 10.2% | 12224 | 208 | 0 | 289 | 0.00 | #3c555a | #1a5169 | MINOR FRINGE |  |
| feed-cast-knithat-4 | 220x433 | 535 | 8.9% | 6021 | 15810 | 0 | 213 | 0.27 | #768891 | - | MINOR FRINGE | interior px are blue/teal art or tinted shading, not flat key |
| mixup-cubby-shelf | 1627x601 | 1290 | 9.4% | 13679 | 263 | 0 | 746 | 0.00 | #326070 | #1c576c | MINOR FRINGE |  |
| bunny-legs | 332x139 | 627 | 18.1% | 3464 | 329 | 0 | 148 | 0.01 | #59757d | #335f78 | MINOR FRINGE |  |
| bunny2-legs | 332x139 | 627 | 18.1% | 3464 | 329 | 0 | 148 | 0.01 | #59757d | #335f78 | MINOR FRINGE |  |
| mixup-curtain-valance | 2011x286 | 1359 | 8.2% | 16503 | 36 | 0 | 815 | 0.00 | #2a5869 | #306d84 | MINOR FRINGE |  |
| hum-mallet | 968x743 | 1074 | 10.2% | 10494 | 397 | 0 | 213 | 0.01 | #5b7377 | #225874 | MINOR FRINGE |  |
| shelf-dropdots | 649x852 | 997 | 11.1% | 9009 | 54 | 0 | 387 | 0.00 | #2a4f5c | #295565 | MINOR FRINGE |  |
| sleepybox-cube | 907x900 | 1081 | 10.1% | 10693 | 38 | 0 | 241 | 0.00 | #48605d | #3d627a | MINOR FRINGE |  |
| window-bird | 905x700 | 1101 | 9.5% | 11596 | 327 | 0 | 294 | 0.00 | #596f73 | #23546a | MINOR FRINGE |  |
| mixup-curtain-swag-right | 790x1383 | 1209 | 8.2% | 14674 | 214 | 0 | 647 | 0.00 | #3d6c81 | #3d809e | MINOR FRINGE |  |
| feed-cookie | 893x913 | 1041 | 9.3% | 11208 | 199 | 0 | 571 | 0.00 | #325e73 | #285c76 | MINOR FRINGE |  |
| zebra-body | 571x357 | 730 | 12.9% | 5669 | 276 | 0 | 179 | 0.00 | #5e747c | #275068 | MINOR FRINGE |  |
| meadow-rock-awake | 1008x926 | 1008 | 9.0% | 11257 | 0 | 0 | 1008 | 0.00 | #63797d | #325c70 | MINOR FRINGE |  |
| robot2-body | 637x306 | 813 | 10.1% | 8018 | 128 | 0 | 183 | 0.01 | #526568 | #23586e | MINOR FRINGE |  |
| cat-body | 710x348 | 762 | 9.7% | 7884 | 211 | 0 | 179 | 0.00 | #596b72 | #23536d | MINOR FRINGE |  |
| zebra-legs | 360x171 | 513 | 13.7% | 3752 | 170 | 0 | 141 | 0.01 | #506a75 | #2a546d | MINOR FRINGE |  |
| meadow-rock | 1007x926 | 887 | 7.9% | 11283 | 0 | 0 | 885 | 0.00 | #63797d | #335d6f | MINOR FRINGE |  |
| feed-bread | 935x863 | 857 | 8.0% | 10729 | 232 | 0 | 338 | 0.00 | #456671 | #1d5870 | MINOR FRINGE |  |
| cat-head | 517x440 | 645 | 10.5% | 6156 | 225 | 0 | 138 | 0.00 | #5c7077 | #1d495f | MINOR FRINGE |  |
| feed-chalkboard | 806x1300 | 876 | 6.9% | 12664 | 171 | 0 | 343 | 0.00 | #41616f | #236375 | MINOR FRINGE |  |
| dog-body | 576x342 | 564 | 10.1% | 5574 | 162 | 0 | 193 | 0.00 | #5b7177 | #215573 | MINOR FRINGE |  |
| robot2-legs | 374x233 | 517 | 10.6% | 4883 | 58 | 0 | 142 | 0.01 | #4b5e60 | #295a6e | MINOR FRINGE |  |
| mixup-room | 932x1114 | 825 | 6.6% | 12438 | 6 | 0 | 176 | 0.00 | #385156 | #225566 | MINOR FRINGE |  |
| robot2-head | 484x472 | 525 | 9.1% | 5794 | 126 | 0 | 145 | 0.00 | #586c6f | #2a586d | MINOR FRINGE |  |
| wren-head | 502x409 | 509 | 9.2% | 5520 | 2 | 0 | 463 | 0.00 | #1f6d86 | #24586d | MINOR FRINGE |  |
| wren-body | 564x338 | 491 | 8.6% | 5686 | 13 | 0 | 345 | 0.00 | #266c84 | #295e78 | MINOR FRINGE |  |
| fox-head | 484x420 | 500 | 8.1% | 6209 | 46 | 0 | 126 | 0.00 | #526666 | #155068 | MINOR FRINGE |  |
| fox-legs | 359x277 | 445 | 8.8% | 5061 | 0 | 0 | 131 | 0.01 | #405656 | #165672 | MINOR FRINGE |  |
| cat-legs | 381x149 | 356 | 10.6% | 3364 | 107 | 0 | 120 | 0.01 | #536970 | #255670 | MINOR FRINGE |  |
| fox-body | 586x353 | 481 | 7.4% | 6468 | 15 | 0 | 130 | 0.00 | #465a5b | #1b556e | MINOR FRINGE |  |
| lion-body | 570x331 | 430 | 7.7% | 5549 | 53 | 0 | 163 | 0.00 | #466562 | #22485a | MINOR FRINGE |  |
| wren-legs | 361x147 | 352 | 9.5% | 3708 | 18 | 0 | 274 | 0.00 | #296b85 | #28647c | MINOR FRINGE |  |
| mixup-stage | 1317x575 | 575 | 5.1% | 11320 | 5 | 0 | 117 | 0.00 | #45585b | #336077 | MINOR FRINGE |  |
| feed-plant | 777x1040 | 734 | 3.9% | 18979 | 96 | 0 | 156 | 0.00 | #546c6b | #2c5f79 | MINOR FRINGE |  |
| window-cat-awake | 1055x917 | 612 | 4.6% | 13246 | 0 | 0 | 612 | 0.00 | #314a4f | #366072 | MINOR FRINGE |  |
| sleepybox-drawer | 1034x697 | 544 | 5.2% | 10495 | 11 | 0 | 321 | 0.00 | #295f7e | #28637f | MINOR FRINGE |  |
| mixup-button | 921x925 | 534 | 4.9% | 10940 | 58 | 0 | 135 | 0.00 | #4b6064 | #275673 | MINOR FRINGE |  |
| dog-legs | 388x165 | 312 | 8.2% | 3787 | 85 | 0 | 81 | 0.01 | #5a7075 | #275e7c | MINOR FRINGE |  |
| shelf-stack | 656x997 | 529 | 4.5% | 11797 | 71 | 0 | 111 | 0.00 | #4a5e63 | #285569 | MINOR FRINGE |  |
| frog-head | 500x425 | 370 | 6.4% | 5794 | 42 | 0 | 120 | 0.00 | #446963 | #1e4963 | MINOR FRINGE |  |
| king-head | 464x446 | 372 | 6.1% | 6115 | 69 | 0 | 85 | 0.00 | #586d6f | #1f4d66 | MINOR FRINGE |  |
| queen-head | 464x446 | 372 | 6.1% | 6115 | 69 | 0 | 85 | 0.00 | #586d6f | #1f4d66 | MINOR FRINGE |  |
| frog-legs | 387x187 | 310 | 7.2% | 4287 | 10 | 0 | 100 | 0.00 | #406661 | #245876 | MINOR FRINGE |  |
| frog-body | 618x344 | 350 | 6.2% | 5660 | 30 | 0 | 118 | 0.00 | #446962 | #23506d | MINOR FRINGE |  |
| mixup-curtain-swag-left | 786x1393 | 551 | 3.8% | 14689 | 24 | 0 | 145 | 0.00 | #536671 | #44809a | MINOR FRINGE |  |
| owl-head | 498x452 | 379 | 5.3% | 7209 | 20 | 0 | 135 | 0.00 | #4a6568 | #174964 | MINOR FRINGE |  |
| bear-head | 504x430 | 352 | 5.5% | 6457 | 8 | 0 | 170 | 0.00 | #366372 | #174c69 | MINOR FRINGE |  |
| bear2-head | 504x430 | 352 | 5.5% | 6457 | 8 | 0 | 170 | 0.00 | #366372 | #174c69 | MINOR FRINGE |  |
| owl-body | 652x375 | 322 | 5.1% | 6254 | 20 | 0 | 121 | 0.00 | #44636b | #225572 | MINOR FRINGE |  |
| feed-stand-back | 1448x1086 | 177 | 0.1% | 154911 | 14750 | 0 | 177 | 0.08 | #597c6b | - | CLEAN | interior px are blue/teal art or tinted shading, not flat key |
| duck-legs | 392x147 | 293 | 7.3% | 4025 | 1 | 0 | 210 | 0.00 | #226989 | #2c698b | CLEAN |  |
| lion-legs | 374x160 | 275 | 7.5% | 3643 | 17 | 0 | 127 | 0.00 | #3c5e5c | #1c4657 | CLEAN |  |
| duck-body | 575x355 | 285 | 5.1% | 5635 | 9 | 0 | 114 | 0.00 | #3a6171 | #326686 | CLEAN |  |
| duck-head | 503x426 | 281 | 5.1% | 5541 | 5 | 0 | 167 | 0.00 | #2f5c77 | #285b7b | CLEAN |  |
| bear-body | 576x347 | 277 | 5.0% | 5546 | 14 | 0 | 101 | 0.00 | #3c5d6a | #1a5274 | CLEAN |  |
| bear2-body | 576x347 | 277 | 5.0% | 5546 | 14 | 0 | 101 | 0.00 | #3c5d6a | #1a5274 | CLEAN |  |
| feed-cast-scarf-1 | 235x873 | 239 | 3.0% | 8080 | 196 | 1 | 245 | 0.00 | #526d6c | #2d5e6d | CLEAN |  |
| bear-legs | 377x150 | 188 | 5.4% | 3497 | 10 | 0 | 90 | 0.00 | #3a5e6b | #1b5577 | CLEAN |  |
| bear2-legs | 377x150 | 188 | 5.4% | 3497 | 10 | 0 | 90 | 0.00 | #3a5e6b | #1b5577 | CLEAN |  |
| owl-legs | 341x132 | 183 | 5.3% | 3475 | 1 | 0 | 76 | 0.00 | #3a5d68 | #1a5573 | CLEAN |  |
| feed-cast-scarf-4 | 233x870 | 274 | 3.2% | 8605 | 65 | 0 | 345 | 0.00 | #4f6a6a | #2d5e6d | CLEAN |  |
| feed-cast-scarf-5 | 233x871 | 265 | 3.1% | 8456 | 91 | 0 | 375 | 0.00 | #476365 | #2d5e6d | CLEAN |  |
| feed-cast-scarf-2 | 235x871 | 256 | 3.1% | 8245 | 84 | 0 | 419 | 0.00 | #526c6c | #2d5e6d | CLEAN |  |
| songbird-legs | 399x132 | 170 | 4.5% | 3799 | 5 | 0 | 79 | 0.00 | #376173 | #275576 | CLEAN |  |
| feed-cast-scarf-3 | 236x869 | 248 | 2.8% | 8809 | 91 | 0 | 292 | 0.00 | #546f6f | #2d5e6d | CLEAN |  |
| stack-stone-large | 765x400 | 145 | 2.1% | 7057 | 0 | 0 | 160 | 0.00 | #869197 | - | CLEAN |  |
| sleepybox-ball | 766x753 | 155 | 1.7% | 9037 | 0 | 0 | 129 | 0.00 | #1a687e | #386a7f | CLEAN |  |
| mixup-heart-button | 1010x897 | 155 | 1.3% | 12109 | 0 | 0 | 100 | 0.00 | #2d6179 | #356986 | CLEAN |  |
| shelf-board | 1279x156 | 108 | 1.3% | 8390 | 0 | 0 | 13 | 0.00 | #677875 | #346f80 | CLEAN |  |
| stack-stone-small | 337x201 | 61 | 2.0% | 3090 | 0 | 0 | 62 | 0.00 | #848f95 | - | CLEAN |  |
| meadow-stump | 1060x1055 | 96 | 0.7% | 14188 | 0 | 0 | 96 | 0.00 | #455657 | #336375 | CLEAN |  |
| window-curtain-panel | 762x1113 | 63 | 0.6% | 9794 | 1 | 0 | 49 | 0.00 | #728885 | #466363 | CLEAN |  |
| shelf-nameplate | 910x341 | 41 | 0.5% | 7580 | 0 | 0 | 41 | 0.00 | #4f6762 | #325f72 | CLEAN |  |
| hum-frame | 1592x543 | 60 | 0.2% | 27406 | 0 | 0 | 45 | 0.00 | #435751 | #132b3b | CLEAN |  |
| window-dial-face | 941x941 | 27 | 0.2% | 11104 | 2 | 0 | 0 | 0.24 | #2d4848 | - | CLEAN |  |
| stack-stone-medium | 525x272 | 13 | 0.3% | 4365 | 0 | 0 | 13 | 0.00 | #828b93 | - | CLEAN |  |
| window-dial-face-static | 992x992 | 0 | 0.0% | 11722 | 2 | 0 | 0 | 0.31 | - | #528685 | CLEAN | blue content: fringe/interior metrics confounded, eyeball |
| AppIcon/Icon-1024 | 1024x1024 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-20-ipad | 20x20 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-20-ipad@2x | 40x40 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-20@2x | 40x40 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-20@3x | 60x60 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-29-ipad | 29x29 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-29-ipad@2x | 58x58 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-29@2x | 58x58 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-29@3x | 87x87 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-40-ipad | 40x40 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-40-ipad@2x | 80x80 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-40@2x | 80x80 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-40@3x | 120x120 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-60@2x | 120x120 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-60@3x | 180x180 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-76-ipad | 76x76 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-76-ipad@2x | 152x152 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| AppIcon/Icon-83.5-ipad@2x | 167x167 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| BrandHero | 1254x1254 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| bubbles-room | 1023x1537 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-grandmother-1 | 227x397 | 0 | 0.0% | 4206 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-grandmother-2 | 241x398 | 0 | 0.0% | 4104 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-grandmother-3 | 251x398 | 0 | 0.0% | 4274 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-grandmother-4 | 242x396 | 0 | 0.0% | 4243 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-grandmother-5 | 233x392 | 0 | 0.0% | 4416 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-sprout-1 | 210x370 | 0 | 0.0% | 3953 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-sprout-2 | 209x371 | 0 | 0.0% | 3980 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-sprout-3 | 211x370 | 0 | 0.0% | 3980 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-sprout-4 | 210x368 | 0 | 0.0% | 3963 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| feed-cast-sprout-5 | 208x367 | 0 | 0.0% | 3947 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| meadow-spring-moss | 1254x1254 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| shelfroom-day | 1024x1536 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| sleepybox-floor | 1024x1536 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |
| window-room-day | 1024x1536 | 0 | 0.0% | 0 | 0 | 0 | 0 | 0.00 | - | - | CLEAN |  |

## Skipped / legit-blue by name (metrics shown, not flagged)

| imageset | size | edge-fringe px | fringe % | edge band | interior teal px | pocket px | semi-a teal | blue frac | fringe avg | bg est | verdict | note |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| window-cloud | 946x693 | 12647 | 86.2% | 14674 | 8332 | 4 | 3526 | 0.03 | #657f88 | #437084 | SKIPPED/LEGIT-BLUE | interior px are blue/teal art or tinted shading, not flat key; teal-tinted soft alpha (shadow/wisp) |
| window-trees-night | 1366x635 | 10678 | 71.8% | 14866 | 59891 | 0 | 3474 | 0.90 | #566a9b | #3b6474 | SKIPPED/LEGIT-BLUE | blue content: fringe/interior metrics confounded, eyeball |
| dropdots-token-moon | 333x337 | 916 | 21.9% | 4189 | 212 | 2048 | 2354 | 0.05 | #214b5e | #16384b | SKIPPED/LEGIT-BLUE | flat key-color pocket ~2048px |
| shelfroom-night | 1024x1536 | 0 | 0.0% | 0 | 644289 | 0 | 0 | 0.74 | - | - | SKIPPED/LEGIT-BLUE | blue content: fringe/interior metrics confounded, eyeball |
| window-room-night | 1024x1536 | 0 | 0.0% | 0 | 644289 | 0 | 0 | 0.74 | - | - | SKIPPED/LEGIT-BLUE | blue content: fringe/interior metrics confounded, eyeball |
| window-moon | 854x1031 | 6009 | 44.2% | 13582 | 3553 | 0 | 1166 | 0.01 | #5e7982 | #275972 | SKIPPED/LEGIT-BLUE | interior px are blue/teal art or tinted shading, not flat key |
| window-star-night-light | 563x729 | 1219 | 13.4% | 9080 | 315 | 0 | 245 | 0.00 | #51656b | #2a5572 | SKIPPED/LEGIT-BLUE |  |
| sleepybox-star | 911x894 | 933 | 7.9% | 11792 | 131 | 0 | 477 | 0.00 | #386074 | #275b7e | SKIPPED/LEGIT-BLUE |  |
| window-star-lamp-off | 724x1074 | 955 | 6.9% | 13843 | 191 | 0 | 237 | 0.00 | #546a6a | #366f87 | SKIPPED/LEGIT-BLUE |  |
| window-star-lamp-on | 725x1071 | 656 | 4.7% | 13893 | 64 | 0 | 192 | 0.00 | #516b6b | #38748c | SKIPPED/LEGIT-BLUE |  |
| meadow-winter-ground-night | 1254x1254 | 0 | 0.0% | 0 | 0 | 0 | 0 | 1.00 | - | - | SKIPPED/LEGIT-BLUE | blue content: fringe/interior metrics confounded, eyeball |

## Visual spot-checks performed

- shelfroom-shelf: flat key-teal slab fills the between-boards opening — confirmed pocket (231k px).
- feed-cup: key-teal disc inside handle hole — confirmed pocket.
- feed-basket: keyed bg was TEXTURED bright cyan (#0d9cb5-ish), not flat #3E6877; handle holes still filled with it — confirmed pocket; silhouette has visible dark-blue fringe.
- shelf-hum: flat teal wedge under the mallet — confirmed pocket; one xylophone bar is legit blue.
- meadow-rosette: visible blue-gray halo around cream petals — confirmed fringe.
- meadow-dandelion: teal-gray tint in white wisps — confirmed fringe/soft-alpha contamination.
- meadow-butterfly: opaque dark-teal shadow blob under wing — confirmed tinted-shadow artifact.
- feed-berry (blueberries), songbird-* (blue bird), feed-cast-knithat-* (blue sweater), feed-stand-back (sky through window), shelf-bubbles (teal felt balls), dropdots-board rings: legitimately blue/teal content driving the spec interior metric; only their pocket/fringe-on-warm signals were trusted.
