import Foundation

public enum SoundPackLibrary {
    public static let all: [SoundPack] = recipes.map { recipe in
        SoundPack(
            id: recipe.id,
            name: recipe.name,
            summary: recipe.summary,
            gain: recipe.gain,
            pitchJitterRange: recipe.pitchJitterRange,
            sampleGroups: SoundSynthesizer.renderSamples(for: recipe)
        )
    }

    public static func pack(id: String) -> SoundPack? {
        all.first(where: { $0.id == id })
    }

    private static let recipes: [PackRecipe] = [
        PackRecipe(
            id: "linear",
            name: "Linear",
            summary: "Soft nylon-style taps with a smooth, low resonance and restrained click.",
            gain: 0.86,
            pitchJitterRange: -0.025...0.025,
            baseRecipe: TimbreRecipe(
                bodyFrequency: 152,
                overtoneFrequency: 330,
                clickFrequency: 1_650,
                bodyMix: 0.7,
                clickMix: 0.28,
                noiseMix: 0.08,
                duration: 0.042,
                decay: 0.018,
                gain: 0.72
            )
        ),
        PackRecipe(
            id: "tactile",
            name: "Tactile",
            summary: "A midrange bump with a woody click and a little more body on larger keys.",
            gain: 0.92,
            pitchJitterRange: -0.03...0.03,
            baseRecipe: TimbreRecipe(
                bodyFrequency: 178,
                overtoneFrequency: 420,
                clickFrequency: 2_100,
                bodyMix: 0.72,
                clickMix: 0.4,
                noiseMix: 0.12,
                duration: 0.05,
                decay: 0.022,
                gain: 0.78
            )
        ),
        PackRecipe(
            id: "clicky",
            name: "Clicky",
            summary: "Sharper, brighter clicks with extra top-end bite and shorter decay.",
            gain: 0.9,
            pitchJitterRange: -0.035...0.035,
            baseRecipe: TimbreRecipe(
                bodyFrequency: 205,
                overtoneFrequency: 520,
                clickFrequency: 2_650,
                bodyMix: 0.6,
                clickMix: 0.58,
                noiseMix: 0.16,
                duration: 0.038,
                decay: 0.015,
                gain: 0.74
            )
        )
    ]
}
