$ = require "jquery"
classNames = require "classnames"
{capitalize, has, isFunction} = require "lodash"

{ajax} = require "core/ajax.coffee"
lang = require "core/lang.coffee"
{error, notice} = require "core/messages.coffee"
routes = require "lib/routes.coffee"

prefix =
  area: 'vote_area_'
  total: 'vote_total_'
  count: 'vote_count_'

voteTargets =
  comment: 'idComment'
  topic: 'idTopic'
  blog: 'idBlog'
  user: 'idUser'

vote = (idTarget, objVote, value, type) ->
  unless voteTargets[type]
    return false

  objVote = $(objVote)
  params = {}
  params['value'] = value
  params[voteTargets[type]] = idTarget

  ajax routes.vote[type], params, (result) ->
    onVote idTarget, objVote, value, type, result


onVote = (idTarget, objVote, value, type, result) ->
  if result.bStateError
    error null, result.sMsg
    return
  notice null, result.sMsg

  iRating = parseFloat result.iRating
  iCountVote = parseFloat result.iCountVote

  divVoting = $ "##{prefix.area}#{type}_#{idTarget}"
  divTotal = $ "##{prefix.total}#{type}_#{idTarget}"
  divCount = $ "##{prefix.count}#{type}_#{idTarget}"

  divVoting.removeClass classNames "vote-count-positive", "vote-count-negative", "vote-count-zero", "vote-count-mixed", "not-voted"
  divVoting.addClass classNames "voted",
    "voted-up": value > 0
    "voted-down": value < 0
    "voted-zero": value == 0
    "vote-count-positive": iRating > 0
    "vote-count-negative": iRating < 0
    "vote-count-zero": iRating == 0 and iCountVote == 0
    "vote-count-mixed": iRating == 0 and iCountVote > 0

  if divCount.length > 0 and result.iCountVote then divCount.text parseInt(result.iCountVote)
  divTotal.text if iRating > 0 then "+#{iRating}" else if iRating < 0 then result.iRating else 0
  divTotal[0].dataset.count = iCountVote

  method = "onVote#{capitalize type}"
  if has(@, method) && isFunction @[method]
    @[method] idTarget, objVote, value, type, result

onVoteUser = (idTarget, objVote, value, type, result) ->
  $("#user_skill_#{idTarget}").text result.iSkill

getVotes = (targetId, targetType, el) ->
  params = {}
  params['targetId'] = targetId
  params['targetType'] = targetType

  ajax routes.vote.getVotes, params, this.onGetVotes.bind({"orig":this,"control":el})
  el.dataset.queryState = "query"
  return false

__makeProfileLink = (path, data) ->
  el = document.createElement "a"
  if path != null and data.name != null
    el.href = "/profile/"+path
    el.target = "_blank"
    el.className = "ls-user has-avatar"
    avatar = document.createElement "img"
    avatar.src = data.avatar
    el.appendChild avatar
    el.appendChild document.createTextNode(data.name)
  else
    el.href = "javascript://"
    el.className = "ls-user undefined"
    el.appendChild document.createTextNode("—")
  return el

onGetVotes = (result) ->
  if result.bStateError
    error null, result.sMsg
  else
    voteSum = 0
    if result.aVotes.length > 0
      vl = document.createElement "div"
      vl.className = "vote-list"
      for i in [0...result.aVotes.length]
        vote = result.aVotes[i]
        voteSum += vote.value
        line = document.createElement "div"
        profileLink = __makeProfileLink(vote.voterName, {
          name: vote.voterName,
          avatar: vote.voterAvatar
        });
        line.appendChild profileLink
        
        time = document.createElement "time"
        time.datetime = vote.date
        date = new Date(Date.parse(vote.date))
        now = new Date()
        timeString = if date.getDate() != now.getDate() or date.getMonth() != now.getMonth() or date.getFullYear() != now.getFullYear() then date.toLocaleString() else date.toLocaleTimeString()
        time.appendChild document.createTextNode(timeString)
        line.appendChild time
        
        voteValue = document.createElement "span"
        voteValue.dataset.value = if vote.value == 0 then "0" else (if vote.value > 0 then "+" else "−") + Math.abs(vote.value).toString()
        voteValue.className = "vote"
        line.appendChild voteValue
        
        vl.appendChild line
      
      vl_wrapper = document.createElement "div"
      vl_wrapper.className = "vote-list-wrapper hidden"
      vl_wrapper.appendChild vl
      if this.control.parentNode.parentNode.classList.contains("comment-actions")
        this.control.parentNode.insertBefore vl_wrapper, this.control.parentNode.firstChild
      else
        this.control.parentNode.parentNode.parentNode.insertBefore vl_wrapper, this.control.parentNode.parentNode.nextSibling
      setTimeout DOMTokenList.prototype.remove.bind(vl_wrapper.classList), 10, "hidden"
      
      context = {
        "target":vl_wrapper,
        "eventTarget":window
      }
      context.callback = this.orig.onVotesListLeaved.bind context
      context.eventTarget.addEventListener "click", context.callback
    
    if parseInt(this.control.dataset.count) != result.aVotes.length
      this.control.parentNode.classList.remove this.orig.options.classes.negative
      this.control.parentNode.classList.remove this.orig.options.classes.positive
      this.control.parentNode.classList.remove this.orig.options.classes.mixed
      if voteSum > 0
        this.control.textContent = "+" + voteSum.toString()
        this.control.parentNode.classList.add this.orig.options.classes.positive
      else
        this.control.textContent = voteSum.toString()
        if voteSum < 0
          this.control.parentNode.classList.add this.orig.options.classes.negative
        else
          this.control.parentNode.classList.add this.orig.options.classes.mixed
      
      this.control.dataset.count = result.aVotes.length.toString()
  delete this.control.dataset.queryState

onVotesListLeaved = (e) ->
  if this.target != e.target and e.target.tagName != "A" and !this.target.contains(e.target)
    this.target.classList.add "hidden"
    setTimeout Node.prototype.removeChild.bind(this.target.parentNode), 500, this.target
    this.eventTarget.removeEventListener e.type, this.callback


module.exports = {vote, getVotes}