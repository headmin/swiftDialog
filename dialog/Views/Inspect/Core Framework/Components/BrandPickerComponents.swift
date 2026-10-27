//
//  BrandPickerComponents.swift
//  dialog
//
//  Brand picker grid and cards for multi-brand selection.
//

import SwiftUI

// MARK: - Brand Picker Components

/// Grid of brand cards for multi-brand onboarding selection
struct BrandPickerGrid: View {
    let brands: [InspectConfig.BrandConfig]
    let columns: Int
    @Binding var selectedBrandId: String?
    let accentColor: Color

    init(
        brands: [InspectConfig.BrandConfig],
        columns: Int = 2,
        selectedBrandId: Binding<String?>,
        accentColor: Color = .accentColor
    ) {
        self.brands = brands
        self.columns = columns
        self._selectedBrandId = selectedBrandId
        self.accentColor = accentColor
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(brands) { brand in
                BrandCard(
                    brand: brand,
                    isSelected: selectedBrandId == brand.id,
                    accentColor: accentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedBrandId = brand.id
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

/// Individual brand card showing logo, name, and accent stripe
struct BrandCard: View {
    let brand: InspectConfig.BrandConfig
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    private var brandColor: Color {
        if let hex = brand.highlightColor {
            return Color(hex: hex)
        }
        return accentColor
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(brandColor)
                    .frame(height: 6)

                VStack(spacing: 12) {
                    Spacer(minLength: 8)

                    brandImage
                        .frame(width: 64, height: 64)

                    Text(brand.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = brand.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 12)
            }
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? brandColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
            )
            .overlay(
                isSelected ?
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(brandColor)
                        .font(.title2)
                        .padding(8)
                    : nil,
                alignment: .topTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var brandImage: some View {
        if let logoPath = brand.logoPath, let nsImage = InspectImageCache.shared.image(atPath: logoPath) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else if let sfSymbol = brand.sfSymbol {
            Image(systemName: sfSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(brandColor)
        } else {
            Image(systemName: "building.2.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(brandColor)
        }
    }
}

