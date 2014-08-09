{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend, (<>))
import           Hakyll
import           Text.Pandoc.Options as Pandoc.Options
import Data.Map            (member)

--------------------------------------------------------------------------------
-- Pandoc
--------------------------------------------------------------------------------


pandocWriterOptions :: Pandoc.Options.WriterOptions
pandocWriterOptions = defaultHakyllWriterOptions
    { Pandoc.Options.writerHtml5 = True
    , Pandoc.Options.writerHtmlQTags = True
    , Pandoc.Options.writerReferenceLinks = True
    , Pandoc.Options.writerSectionDivs = True
    }


tocWriterOptions :: Pandoc.Options.WriterOptions
tocWriterOptions = pandocWriterOptions
    { writerTableOfContents = True
    , writerTemplate =
        "$if(toc)$<div id=\"toc\"><h2>Contents</h2>\n$toc$</div>\n$endif$$body$"
    , writerStandalone = True
    , writerHTMLMathMethod = MathJax ""
    }

--------------------------------------------------------------------------------
-- Site building
--------------------------------------------------------------------------------


main :: IO ()
main = hakyllWith config $ do


    -- put all the images in /images
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler


    -- copy site icon to `favicon.ico`
    match "images/favicon.ico" $ do
        route   (constRoute "favicon.ico")
        compile copyFileCompiler


    -- route the fonts
    match "font/*" $ do
        route   idRoute
        compile copyFileCompiler


    -- route my extra files
    match "files/**" $ do
        route   idRoute
        compile copyFileCompiler


    -- javascript
    match "js/**" $ do
        route   idRoute
        compile copyFileCompiler


    -- route the css
    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler


    -- robots
    match "robots.txt" $ do
        route idRoute
        compile copyFileCompiler


    -- compile the scss and put it in _site/css/
    match "scss/*" $ do
        route $ gsubRoute "scss/" (const "css/") `composeRoutes`
            setExtension "css"
        compile $ getResourceString
            >>= withItemBody
                ( unixFilter "sass"
                    [ "-s"
                    , "--scss"
                    , "compressed"]
                )
            >>= return . fmap compressCss


    -- make top-level pages
    match "pages/*" $ do
        route $ gsubRoute "pages/" (const "") `composeRoutes`
            setExtension "html"
        compile $ pandocCompilerWith defaultHakyllReaderOptions tocWriterOptions
            >>= loadAndApplyTemplate "templates/default.html" defaultCtx
            >>= relativizeUrls


    match "blog/*" $ do
        route $ setExtension "html"
        let context = postCtx <> defaultCtx
        compile $
            pandocCompilerWith defaultHakyllReaderOptions tocWriterOptions
            >>= loadAndApplyTemplate "templates/post.html" context
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" context
            >>= relativizeUrls


    create ["blog.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "blog/*"
            let archiveCtx =
                    constField     "rssblog" "" `mappend`
                    listField      "posts" postCtx (return posts) `mappend`
                    constField     "title" "Blog" `mappend`
                    defaultCtx

            makeItem ("" :: String)
                >>= loadAndApplyTemplate "templates/blog.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "blog/*" "content"
            renderAtom myFeedConfiguration feedCtx posts


    create ["404.html"] $ do
        route idRoute
        compile $ do
            let notFoundCtx =
                    constField "title" "404 you're lost" `mappend`
                    defaultCtx
            makeItem ""
                >>= loadAndApplyTemplate "templates/default.html" notFoundCtx


    match "pages/index.html" $ do
        route $ gsubRoute "pages/" (const "") `composeRoutes` idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "blog/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultCtx

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls


    match "templates/*" $ compile templateCompiler


--------------------------------------------------------------------------------

config :: Configuration
config = defaultConfiguration
    {   deployCommand = "rsync --checksum -ave 'ssh' _site/* "
                        ++ "athen@ephesus:/srv/http/nathantypanski.com"
      , inMemoryCache = True
      , previewPort = 8080
    }
--------------------------------------------------------------------------------


myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Nathan's Blog"
    , feedDescription = "Linux and software development"
    , feedAuthorName  = "Nathan Typanski"
    , feedAuthorEmail = "feed@nathantypanski.com"
    , feedRoot        = "http://www.nathantypanski.com"
    }

mathCtx :: Context a
mathCtx = field "mathjax" $ \item -> do
    metadata <- getMetadata $ itemIdentifier item
    return $ if "mathjax" `member` metadata
                  then "<script type=\"text/javascript\" src=\"http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML\"></script>"
                  else ""

postCtx :: Context String
postCtx =
    modificationTimeField "modified" "%B %e, %Y" `mappend`
    dateField "date" "%B %e, %Y" `mappend`
    defaultCtx

defaultCtx :: Context String
defaultCtx = defaultContext `mappend`
             mathCtx
