library(igraph)
g = read.graph('/Users/rodrigorgs/research/eclipse/git-logs/nets/eclipse-commiter-project.arc', format='ncol', directed=F)

for (i in V(g)) {
  if (substr(V(g)[i]$name, 0, 11) == 'org.eclipse') {
    V(g)[i]$type = TRUE
  }
  else {
  	V(g)[i]$type = FALSE
  }
}

bip = bipartite.projection(g)

write.graph(bip$proj2, '/tmp/bli.gml', 'gml')

