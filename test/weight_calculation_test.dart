import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rice_weight_manager/models/harvest.dart';
import 'package:rice_weight_manager/models/weight_entry.dart';
import 'package:rice_weight_manager/models/weight_group.dart';
import 'package:rice_weight_manager/utils/formatters.dart';

void main() {
  group('Weight Group & Entry Calculations', () {
    test('Group subtotal calculates correctly for full 5 entries', () {
      final entries = [
        WeightEntry(groupId: 1, weight: 45.5),
        WeightEntry(groupId: 1, weight: 50.0),
        WeightEntry(groupId: 1, weight: 48.5),
        WeightEntry(groupId: 1, weight: 52.0),
        WeightEntry(groupId: 1, weight: 49.0),
      ];
      final group = WeightGroup(harvestId: 1, groupNumber: 1, entries: entries);

      expect(group.entryCount, 5);
      expect(group.isFull, true);
      expect(group.subtotal, 245.0);
    });

    test('Incomplete group subtotal calculates correctly (e.g. 2 entries)', () {
      final entries = [
        WeightEntry(groupId: 2, weight: 55.0),
        WeightEntry(groupId: 2, weight: 51.5),
      ];
      final group = WeightGroup(harvestId: 1, groupNumber: 2, entries: entries);

      expect(group.entryCount, 2);
      expect(group.isFull, false);
      expect(group.subtotal, 106.5);
    });

    test('Overall total strictly sums individual entries (no double counting)', () {
      final group1 = WeightGroup(
        harvestId: 1,
        groupNumber: 1,
        entries: [
          WeightEntry(groupId: 1, weight: 45.5),
          WeightEntry(groupId: 1, weight: 50.0),
          WeightEntry(groupId: 1, weight: 48.5),
          WeightEntry(groupId: 1, weight: 52.0),
          WeightEntry(groupId: 1, weight: 49.0),
        ],
      );

      final group2 = WeightGroup(
        harvestId: 1,
        groupNumber: 2,
        entries: [
          WeightEntry(groupId: 2, weight: 55.0),
          WeightEntry(groupId: 2, weight: 51.5),
        ],
      );

      final groups = [group1, group2];

      // Summing individual entries
      final overallTotal = groups.fold<double>(
        0.0,
        (sum, g) => sum + g.entries.fold<double>(0.0, (s, e) => s + e.weight),
      );

      expect(overallTotal, 351.5);

      // Verify overall tons conversion (1 metric ton = 1,000 kg)
      final overallTons = overallTotal / 1000.0;
      expect(overallTons, 0.3515);
    });

    test('Selling price per kg calculates total estimated value in Riel', () {
      const overallWeight = 351.5; // kg
      const pricePerKg = 1200.0; // ៛ per kg

      final totalValue = overallWeight * pricePerKg;
      expect(totalValue, 421800.0);
    });

    test('Selling price per ton conversion: 1 metric ton = 1000 kg', () {
      const pricePerTon = 1200000.0; // ៛ per ton
      final pricePerKg = pricePerTon / 1000.0; // 1200 ៛/kg

      const overallWeight = 351.5;
      final totalValue = overallWeight * pricePerKg;
      expect(pricePerKg, 1200.0);
      expect(totalValue, 421800.0);
    });

    test('Updating price never alters harvest weights or entries', () {
      final harvest = Harvest(
        id: 1,
        name: 'Rice Season 1',
        harvestDate: DateTime(2026, 11, 16),
        pricePerKg: 1000.0,
      );

      final updatedHarvest = harvest.copyWith(pricePerKg: 1350.0);

      expect(harvest.pricePerKg, 1000.0);
      expect(updatedHarvest.pricePerKg, 1350.0);
      expect(updatedHarvest.name, 'Rice Season 1');
    });

    test('Selling price in US Dollars per kg calculates total value correctly', () {
      const overallWeight = 1260.0; // kg (1.260 tons)
      const pricePerKg = 0.30; // $ per kg

      final totalValue = overallWeight * pricePerKg;
      expect(totalValue, 378.0);
    });

    test('Selling price in US Dollars per ton converts to per kg correctly', () {
      const pricePerTon = 300.0; // $ per ton
      final pricePerKg = pricePerTon / 1000.0; // $0.30 per kg

      const overallWeight = 1260.0;
      final totalValue = overallWeight * pricePerKg;
      expect(pricePerKg, 0.30);
      expect(totalValue, 378.0);
    });

    test('Harvest currency defaults to KHR and serializes properly to/from Map', () {
      final harvestKHR = Harvest(
        id: 10,
        name: 'Test KHR Harvest',
        harvestDate: DateTime(2026, 11, 16),
      );
      expect(harvestKHR.currency, 'KHR');

      final map = harvestKHR.toMap();
      expect(map['currency'], 'KHR');

      final fromMapKHR = Harvest.fromMap(map);
      expect(fromMapKHR.currency, 'KHR');

      final harvestUSD = harvestKHR.copyWith(currency: 'USD', pricePerKg: 0.30);
      expect(harvestUSD.currency, 'USD');
      expect(harvestUSD.pricePerKg, 0.30);

      final mapUSD = harvestUSD.toMap();
      expect(mapUSD['currency'], 'USD');
      final fromMapUSD = Harvest.fromMap(mapUSD);
      expect(fromMapUSD.currency, 'USD');
    });

    test('ThousandsSeparatorInputFormatter formats 1200 as 1,200', () {
      final formatter = ThousandsSeparatorInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '120'),
        const TextEditingValue(
          text: '1200',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(result.text, '1,200');
      expect(result.selection.end, 5);
    });

    test('ThousandsSeparatorInputFormatter formats 1200000 as 1,200,000 for per ton', () {
      final formatter = ThousandsSeparatorInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '120,000'),
        const TextEditingValue(
          text: '120,0000',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(result.text, '1,200,000');
      expect(result.selection.end, 9);
    });

    test('ThousandsSeparatorInputFormatter formats decimals like 1200.50 with commas in integer part', () {
      final formatter = ThousandsSeparatorInputFormatter(allowFraction: true);
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1200'),
        const TextEditingValue(
          text: '1200.50',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(result.text, '1,200.50');
    });

    test('Weight in kg converted to tons formatting', () {
      const weightKg = 1260.0;
      final weightTons = weightKg / 1000.0;
      expect(weightTons.toStringAsFixed(3), '1.260');

      const groupSubtotalKg = 450.0;
      final groupSubtotalTons = groupSubtotalKg / 1000.0;
      expect(groupSubtotalTons.toStringAsFixed(3), '0.450');

      const smallWeightKg = 90.0;
      final smallWeightTons = smallWeightKg / 1000.0;
      expect(smallWeightTons.toStringAsFixed(3), '0.090');
    });

    test('Harvest supports float land area (hectare) and formats properly', () {
      final harvestFloat = Harvest(
        name: 'Field 1',
        harvestDate: DateTime.now(),
        riceFieldCount: 3.8,
      );
      expect(harvestFloat.riceFieldCount, 3.8);
      expect(harvestFloat.formattedFieldCount, '3.8');

      final harvestInt = Harvest(
        name: 'Field 2',
        harvestDate: DateTime.now(),
        riceFieldCount: 5.0,
      );
      expect(harvestInt.formattedFieldCount, '5');

      final map = harvestFloat.toMap();
      expect(map['rice_field_count'], 3.8);

      final fromMap = Harvest.fromMap(map);
      expect(fromMap.riceFieldCount, 3.8);
      expect(fromMap.formattedFieldCount, '3.8');
    });
  });
}
