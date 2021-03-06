#' Post a tex output to a Slack channel
#'
#' Unlike the \code{\link{dev_slackr}} function, this one takes a \code{tex} object,
#' eliminating the need write to pdf and convert to png to pass to slack.
#'
#' @param obj character object containing tex to compile
#' @param channels list of channels to post image to
#' @param ext character, type of format to return, can be tex, pdf, or any image device, Default: 'png'
#' @param path character, path to save tex_preview outputs, if NULL then tempdir is used, Default: NULL
#' @param api_token the Slack full API token (chr)
#' @param ... other arguments passed to \code{\link[texPreview]{tex_preview}}, see Details
#' @note You need to setup a full API token (i.e. not a webhook & not OAuth) for this to work
#'       Also, you can pass in \code{add_user=TRUE} as part of the \code{...}
#'       parameters and the Slack API will post the message as your logged-in user
#'       account (this will override anything set in \code{username})
#' @return \code{httr} response object (invisibly)
#' @details Please make sure \code{texPreview} package is installed before running this function.
#'          For TeX setup refer to the
#'          \href{https://github.com/mrkaye97/slackr#latex-for-tex_slackr}{Setup notes on \code{LaTeX}}.
#' @examples
#' \dontrun{
#' slackr_setup()
#' obj=xtable::xtable(mtcars)
#' tex_slackr(obj,print.xtable.opts=list(scalebox=getOption("xtable.scalebox", 0.8)))
#'
#' tex_slackr(obj,ext = 'pdf',print.xtable.opts=list(scalebox=getOption("xtable.scalebox", 0.8)))
#'
#' tex_slackr(obj,ext = 'tex',print.xtable.opts=list(scalebox=getOption("xtable.scalebox", 0.8)))
#'
#' tex_slackr(obj,path='testdir',print.xtable.opts=list(scalebox=getOption("xtable.scalebox", 0.8)))
#' }
#' @seealso
#'  \code{\link[texPreview]{tex_preview}} \code{\link[xtable]{print.xtable}}
#' @author Jonathan Sidi [aut]
#' @export
tex_slackr <- function(obj,
                     channels=Sys.getenv("SLACK_CHANNEL"),
                     bot_user_oauth_token=Sys.getenv("SLACK_BOT_USER_OAUTH_TOKEN"),
                     ext='png',
                     path=NULL,
                     ...) {

  # check if texPreview is installed, if not provide feedback
  check_tex_pkg()

  loc <- Sys.getlocale('LC_CTYPE')
  Sys.setlocale('LC_CTYPE','C')
  on.exit(Sys.setlocale("LC_CTYPE", loc))

  if(!is.null(path)){
    td <- path
  }else{
    td <- file.path(tempdir(),'slack')
  }

  if(!dir.exists(td)) dir.create(td)

  texPreview::tex_preview(
    obj = obj,
    stem = 'slack',
    fileDir = td,
    imgFormat = ifelse(ext=='tex','png',ext),
    ...)

  modchan <- slackr_chtrans(channels)

  res <- POST(url="https://slack.com/api/files.upload",
              add_headers(`Content-Type`="multipart/form-data"),
              body=list(file=upload_file(file.path(td,paste0('slack.',ext))),
                        token=bot_user_oauth_token,
                        channels=modchan))

  #cleanup
  file.remove(list.files(td,pattern = 'Doc',full.names = TRUE))

  if(is.null(path)) unlink(td,recursive = TRUE)

  invisible(res)

}



#' @description Install or load texPreview package,
#'   inspired by the \code{parsnip} package
#'
check_tex_pkg <- function() {
  is_installed <- try(
    suppressPackageStartupMessages(
      requireNamespace('texPreview', quietly = TRUE)),
    silent = TRUE)

  if (!is_installed) {
    stop('texPreview package is not installed, run ?tex_slackr and see Details.', call. = FALSE)
  }
}
