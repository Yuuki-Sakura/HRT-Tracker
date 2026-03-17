import SwiftUI
import WebKit

struct MarkdownWebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

extension MarkdownWebView {
    func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // 读取 markdown 文件
        var mdContent = ""
        if let url = Bundle.main.url(forResource: "Algorithm Explanation", withExtension: "md"),
           let data = try? Data(contentsOf: url),
           let s = String(data: data, encoding: .utf8) {
            mdContent = s
        }
        let safeContent = mdContent

        let base = Bundle.main.url(forResource: "katex.min", withExtension: "css")?.deletingLastPathComponent()
                ?? Bundle.main.bundleURL

        let html = """
        <!DOCTYPE html><html><head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <link rel="stylesheet" href="github-markdown.min.css">
          <link rel="stylesheet" href="katex.min.css">
          <link rel="stylesheet" href="texmath.min.css">
          <script src="katex.min.js"></script>
          <script src="markdown-it.min.js"></script>
          <script src="markdown-it-texmath.min.js"></script>
          <script src="markdown-it-footnote.min.js"></script>
          <style>
            .markdown-body {
                padding: 16px;
                font-family: unset;
            }
            .katex-display { overflow-x: auto; overflow-y: hidden; }
          </style>
        </head><body>
          <script type="text/plain" id="mdsrc">\(safeContent)</script>
          <article class="markdown-body">
            <div id="content"></div>
          </article>
          <script>
            var md = document.getElementById('mdsrc').textContent;
            var mdi = markdownit({ html: true })
                        .use(texmath, { engine: katex, delimiters: 'dollars' })
                        .use(markdownitFootnote);
            document.getElementById('content').innerHTML = mdi.render(md);
          </script>
        </body></html>
        """

        webView.load(Data(html.utf8), mimeType: "text/html",
                     characterEncodingName: "utf-8", baseURL: base)
        return webView
    }
}

struct AlgorithmExplanationView: View {
    var body: some View {
        MarkdownWebView()
            .navigationTitle(String(localized: "settings.model_title"))
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AlgorithmExplanationView()
    }
}
