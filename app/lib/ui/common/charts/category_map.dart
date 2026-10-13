import 'package:flutter/material.dart';

import 'package:spendwise/ui/common/charts/category_map_layout.dart';
import 'package:spendwise/ui/theme/spendwise_text.dart';

export 'package:spendwise/ui/common/charts/category_map_layout.dart';

part 'category_map/category_map_helpers.dart';
part 'category_map/category_map_tile.dart';
part 'category_map/category_map_view.dart';
part 'category_map/category_map_block.dart';
part 'category_map/category_map_labels.dart';

// MARK: - Constants

const _semiBoldWeight = FontWeight.w600;

const _percentFactor = 100.0;

const _emptyExtent = 0.0;

const _shareFractionDigits = 1;

const _labelInset = 20.0;

const _labelFontSize = 12.0;

const _nameMaxLines = 2;

const _shareMaxLines = 1;

const _nameShareGap = 2.0;

const _minBlockSize = 4.0;

const _blockInset = 2.0;
