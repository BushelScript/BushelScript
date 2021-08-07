import Bushel
import TooMuchTheme
import Defaults

var defaultSizeHighlightStyles: Styles? = try? makeHighlightStyles()

func makeHighlightStyles(fontSize: CGFloat? = nil) throws -> Styles {
    let themeFile = try makeThemesDir().appendingPathComponent(Defaults[.themeFileName])
    let plist = try Data(contentsOf: themeFile)
    let theme = try PropertyListDecoder().decode(Theme.self, from: plist)
    
    let fontProvider = FontProvider(size: fontSize ?? Defaults[.sourceCodeFont].pointSize)
    return try [
        .comment: theme.attributes(for: Scope("source.bushelscript comment.bushelscript"), fontProvider: fontProvider),
        .keyword: theme.attributes(for: Scope("source.bushelscript keyword.bushelscript"), fontProvider: fontProvider),
        .operator: theme.attributes(for: Scope("source.bushelscript keyword.operator.bushelscript"), fontProvider: fontProvider),
        .type: theme.attributes(for: Scope("source.bushelscript storage.type.bushelscript"), fontProvider: fontProvider),
        .property: theme.attributes(for: Scope("source.bushelscript support.variable.property.bushelscript"), fontProvider: fontProvider),
        .constant: theme.attributes(for: Scope("source.bushelscript support.type.symbol.bushelscript"), fontProvider: fontProvider),
        .command: theme.attributes(for: Scope("source.bushelscript support.function.command.bushelscript"), fontProvider: fontProvider),
        .parameter: theme.attributes(for: Scope("source.bushelscript support.constant.parameter.bushelscript"), fontProvider: fontProvider),
        .variable: theme.attributes(for: Scope("source.bushelscript variable.other.bushelscript"), fontProvider: fontProvider),
        .resource: theme.attributes(for: Scope("source.bushelscript entity.name.type.bushelscript"), fontProvider: fontProvider),
        .number: theme.attributes(for: Scope("source.bushelscript constant.numeric.bushelscript"), fontProvider: fontProvider),
        .string: theme.attributes(for: Scope("source.bushelscript string.quoted.bushelscript"), fontProvider: fontProvider),
        .weave: theme.attributes(for: Scope("source.bushelscript string.interpolated.bushelscript"), fontProvider: fontProvider),
    ]
}

private struct FontProvider: TooMuchTheme.FontProvider {
    
    var size: CGFloat
    
    func provideFont(bold: Bool, italic: Bool) -> Any {
        NSFontManager.shared.convert(
            NSFontManager.shared.convert(
                NSFontManager.shared.convert(Defaults[.sourceCodeFont], toHaveTrait: bold ? .boldFontMask : .unboldFontMask),
                toHaveTrait: italic ? .italicFontMask : .unitalicFontMask
            ),
            toSize: size
        )
    }
    
}

func makeThemesDir() throws -> URL {
    let themesDir = try
        FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("BushelScript Editor")
        .appendingPathComponent("Themes")
    try FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true, attributes: nil)
    return themesDir
}
