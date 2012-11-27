##
##  (C) 2012 Andriy Borodiychuk, a.borodiychuk@markusweb.com
##
##  http://markusweb.com/
##
##  License: MIT
##

##
##  Table controls. Table is received either fully, or partially, with server-paginaton and filetrs.
##

angular.module('mwTable', ['ngCookies']).factory 'Table', ($cookieStore, $filter, $rootScope) ->
  "$cookieStore:nomunge, $filter:nomunge, $rootScope:nomunge"

  self = $rootScope.$new()

  # Loading indicator
  self.loading = false
  self.callbacks =
    startLoading: angular.noop
    endLoading:   angular.noop
    errorLoading: angular.noop
  self.limits = [6, 9, 12, 18, 30, 60]
  self.config =
    limit:  20
    page: 1
    mode: 'all'
    search: ''
    orderby: 'id'
    reverse: false
  self.name = '__empty__'
  self.type = 'full' # full or partial
  self.modes = { all: {} }
  self.data =
    ready: false    # Gets true when datat is loaded. Needed to avoid resetting
    raw: []
    display: []
    total: 0
    pages: 0
  self.pagination =
    text: ''
    pages: []
  self.searchbox = '' # Search box for table search. Will be operated within the partial table search

  self.init = (scope, loadData) ->
    if self.name is '__empty__'
      $log.error 'Table name is not set. Must be set via \'self.name = "foo\' in controller.'
    if ['full', 'partial'].indexOf(self.type) is -1
      $log.error 'Table type should be either "full" or "partial" via "self.type"'

    # Default table config is extened with stored, if any
    if $cookieStore.get("tables.#{self.name}")
      angular.extend self.config, $cookieStore.get("tables.#{self.name}")
      self.searchbox = self.config.search

    scope.$watch 'table.data.raw', ->
      self.operate()
    scope.$watch 'table.config', ( (oldObj, newObj) ->
      return if angular.equals oldObj, newObj
      # if table was force reloaded, then remove that option
      if self.config.random?
        delete self.config.random
        forceReload = true
      else
        forceReload = false
      $cookieStore.put "tables.#{self.name}", self.config
      if self.type is 'full'
        self.operate()
        if forceReload
          # self.empty()
          data = loadData (->
            self.endLoading()
            self.data.raw = data
            self.data.ready = true
          ), self.errorLoading
      if self.type is 'partial'
        self.startLoading()
        # self.empty()
        data = loadData (->
          self.endLoading()
          self.data.raw = data.data
          self.data.total = data.total
          self.data.ready = true
        ), self.errorLoading, self.config
    ), true
    self.startLoading()
    if self.type is 'full'
      # self.empty()
      data = loadData (->
        self.endLoading()
        self.data.raw = data
        self.data.ready = true
      ), self.errorLoading
    if self.type is 'partial'
      # self.empty()
      data = loadData (->
        self.endLoading()
        self.data.raw = data.data
        self.data.total = data.total
        self.data.ready = true
      ), self.errorLoading, self.config


  self.operate = ->
    # Do nothing when table is not ready
    return unless self.data.ready
    # Format data
    if self.type is 'full'
      ordered                 = $filter('orderBy')(self.data.raw, self.config.orderby, self.config.reverse)
      mode_filtered           = $filter('filter')(ordered, self.modes[self.config.mode])
      search_filtered         = $filter('filter')(mode_filtered, self.config.search)
      self.data.total   = search_filtered.length
      self.data.pages   = Math.ceil(search_filtered.length / self.config.limit)
      # Reset page if it is too big or too small
      if self.config.page > self.data.pages
        self.config.page = self.data.pages
      self.config.page = 1 if self.config.page < 1
      # Cut the pie
      self.data.display = search_filtered.splice((self.config.page - 1) * self.config.limit, self.config.limit)
    if self.type is 'partial'
      self.data.pages   = Math.ceil(self.data.total / self.config.limit)
      if self.config.page > self.data.pages
        self.config.page = self.data.pages
      self.config.page = 1 if self.config.page < 1
      self.data.display = self.data.raw
    # Calculate pagination
    if self.data.total
      # If not empty
      from = (self.config.page - 1) * self.config.limit + 1
      to = self.config.page * self.config.limit
      # Maximum should not be more than total
      to = if to < self.data.total then to else self.data.total
      self.pagination.text = "#{from} – #{to} von #{self.data.total}"
    else
      # If empty at all
      self.pagination.text = '0 Ergebnisse'
    # Visual pagination
    self.pagination.pages = []
    pages = (num for num in [1..self.data.pages])
    prev = 0
    for page in pages
      if page < 4 or page > self.data.pages - 4 or (page > self.config.page - 3 and page < self.config.page + 3)
        if prev isnt page - 1
          self.pagination.pages.push 0
        self.pagination.pages.push page
        prev = page

  self.setPage = (page) ->
    self.config.page = page if page

  self.setOrderby = (orderby) ->
    if self.config.orderby is orderby
      self.config.reverse = !self.config.reverse
    else
      self.config.orderby = orderby

  # Sometimes we need to force reload table content
  self.reload = ->
    self.config.random = Math.random()

  # Sometimes we need to force reload table content with some delay
  self.delayReload = (seconds = 3) ->
    self.startLoading()
    setTimeout ( -> self.$apply -> self.config.random = Math.random()), seconds * 1000

  # Classname for the column header that does sorting
  self.headerClass = (sorting, additionalClasses = '') ->
    sortingClass = ''
    if self.config.orderby is sorting
      reverse = if self.config.reverse then 'desc' else 'asc'
      sortingClass = "sort-#{reverse}"
    "sortable #{sortingClass} #{additionalClasses}"

  # functions to bind keys and icons to sorters
  self.search = {}
  self.search.set = (value = null) ->
    if value is null
      self.config.search = self.searchbox
    else
      self.config.search = value
      self.searchbox = value


  self.search.clear = ->
    self.config.search = ''
    self.searchbox = ''

  self.startLoading = ->
    self.loading = true
    self.callbacks.startLoading()
  self.endLoading = ->
    self.loading = false
    self.callbacks.endLoading()
  self.errorLoading = ->
    self.callbacks.errorLoading()


  # Do not write anything below this line!
  return self