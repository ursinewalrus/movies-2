require 'sqlite3'
class Movie_organizer
  
def initialize(arg)
  @data = load_data(0)
  @ratings_table = get_data()
  @user_movies = user_movies()
  @mean_ratings = popularity_list()
  if(arg==1)
    start()
  end
end

def start
  puts "Welcome to this my thing. Commands:\nCompare #UserID1 #UserID2 - Compares the two users
Popularity #MovieId - Gets movies popularity
Similar #UserId - Returns top 5 most similar users to you"
  input = ""
  while input != "DONE"
    input = STDIN.gets.chomp
    if input.include? ("Compare")
      inputs = input.split(" ")
      puts "#{inputs[1]} #{inputs[2]}"
      pcent_similar, num_movies = similarity(inputs[1],inputs[2])
      puts "Users are #{pcent_similar}% similar and have seen the same #{num_movies} movies"
    elsif input.include? ("Popularity")
      inputs = input.split(" ")
      pops = popularity(inputs[1])
      puts "Movie popularity is #{pops}"
    elsif input.include?("Similar")
      inputs = input.split(" ")
      answer = most_similar(inputs[1])
      puts "The top 5 users most similar to you are"
      answer.each do |line|
        puts line
      end
    else
      puts "retry command"
    end
    
  end
  puts "Bye."
end

def load_data(arg)

  fileObj = File.new("lib/u.data", "r");
  array = Array.new
  fileObj.each_line do |line|
    array << line 
  end
  fileObj.close 
  if arg == 1 
  db = SQLite3::Database.new "mk-100.db"
  db.execute "CREATE TABLE IF NOT EXISTS Data(user_id INT, movie_id INT, rating INT, timestamp INT)"  		
  db.transaction do |db| 
	array.each do |line|
  		vals = line.split("\t")
  		db.execute "INSERT INTO Data VALUES(#{vals[0]},#{vals[1]},#{vals[2]},#{vals[3]})"
  	end
  end
  db.close

  db = SQLite3::Database.open "mk-100.db"
  fileObj = File.new("lib/u.user", "r"); 
  db.execute "CREATE TABLE IF NOT EXISTS User(user_id INT,age INT,gender INT)"
  user_array = Array.new
  fileObj.each_line do |line|
  	user_array << line
  end
  db.transaction do |db|
  	user_array.each do |line|
  		vals = line.split("#")
  		db.execute "INSERT INTO User VALUES(#{vals[0]},#{vals[1]},#{vals[2]})"
  	end
  end
  db.close

  db = SQLite3::Database.open "mk-100.db"
  fileObj = File.new("lib/u.item", "r"); 
  db.execute "CREATE TABLE IF NOT EXISTS Item(movie_id INT,Genre INT)"
  array2 = Array.new
  fileObj.each_line do |line|
  	array2 << line
  end
  fileObj.close
  item_array = Array.new
  array2.each_with_index do |line,i| x=line.force_encoding("iso-8859-1").gsub("|","\t");item_array[i]=x end
  db.transaction do |db|
  	item_array[0..1681].each do |line|
  		vals = line.split("\t")
  		genre_binary = '1'
  		vals[5..24].each do |v|
  			genre_binary = genre_binary+v
  		end
  		genre_binary = genre_binary.to_i
  		db.execute "INSERT INTO Item VALUES(#{vals[0]},#{genre_binary})"
  	end
  end
  db.close


  end

  return array
end

def get_data
  ratingsTable = Hash.new
  @data.each do |line|
    splitUser = line.split("\t")
    movie = splitUser[1]
    rating = splitUser[2]
    if ratingsTable.has_key?(movie)
      temp = Array.new
      temp = ratingsTable[movie]
      temp << rating
      ratingsTable[movie] = temp
    else 
      temp = Array.new
      temp << rating
      ratingsTable[movie] = temp
    end
  end
  return ratingsTable
end

def user_movies
  userTable = Hash.new
  @data.each do |line|
    splitUser = line.split("\t")
    user = splitUser[0]
    movie = splitUser[1]
    if userTable.has_key?(user)
      temp = Array.new
      temp = userTable[user]
      temp << movie
      userTable[user] = temp
    else 
      temp = Array.new
      temp << movie
      userTable[user] = temp
    end
  end
  return userTable  
end

def popularity_list
  meanHash = Hash.new

  @ratings_table.each do |key, value|
    val = 0
    value.each do |ints|
      val += ints.to_f
    end
    val = val/value.length
    meanHash[key] = val
  end
  meanHash = meanHash.sort_by do |key, value| value end 
  meanHash = meanHash.reverse
  
  file = open("lib/mean_ratings.txt",'w')
  meanHash.each do |k,v|#mean to tot
    numRatings = @ratings_table[k].length.to_i
    file.write("#{k} average rating #{v} with #{numRatings} reviews\n")

  end
  file.close
  return meanHash
end

def popularity(movieId)
  hashSize = @mean_ratings.length
  count = 0
  @mean_ratings.each do |k,v|
    if k.to_i==movieId.to_i
      return hashSize-count
    end
    count = count+1
  end
  return "Movie not found"
end

def similarity(user1,user2)
  similarity=0
  user1_movies = Hash.new
  user2_movies = Hash.new
  @data.each do |line|
    segs = line.split("\t")
  #  puts "#{segs[0]} #{user1}"
    if segs[0].to_i==user1.to_i
      user1_movies[segs[1]] = segs[2].to_i
    end
    if segs[0].to_i==user2.to_i
      user2_movies[segs[1]] = segs[2].to_i
    end
  end
  same_movies = 0
  ratings_dif = 0
  user1_movies.each_key() do |k|
    if user2_movies.has_key?(k)
      same_movies+=1
      ratings_dif += [user1_movies[k],user2_movies[k]].max- [user1_movies[k],user2_movies[k]].min
    end 
  end
  same_movies = same_movies.to_f
  dif_points =  (100/same_movies/4).to_f
  total_dif = dif_points*ratings_dif
  return (100 - total_dif), same_movies
end

def most_similar(user)
  answer = Array.new
  sim_users = movie_overlap(user)
  sim_users[1..5].each do |comparee,v|
    if(user != comparee )
      pcent, movie_num = similarity(user,comparee)
      answer << "You have seen #{movie_num} movies in common with user #{comparee} and have a similarity score of #{pcent}%"
    end
  end
  return answer
end

def movie_overlap(user)
  sim_users = Hash.new
  @user_movies.each do |k,v|
    if user.to_i != k.to_i 
      sames = 0
      v.each do |t| 
        if @user_movies[user].include?(t)
          sames+=1
        end
      end
      if sames >0
       sim_users[k] = sames
      end
    end
    end
sim_users = sim_users.sort_by do |k,v| v end
  sim_users = sim_users.reverse
  return sim_users
end

end 

class Predictor
 
  def initialize(train,makedb)#on first time mkaing predictor, makedb should be 1, all other times can turn to 0
    @m = Movie_organizer.new(0)
    @data = @m.load_data(makedb)#change to 1 if want to make new databse
    @user_movies = user_movie_ratings()#k = user, v= [[movie,rating]]
    @who_seen = who_seen()#k = movie, v =[users]
    @training_num = train
  end
  def user_movie_ratings()
    usermovies = Hash.new
    @data.each do |line|
      splitUser = line.split("\t")
      user = splitUser[0].to_i
      movie = splitUser[1].to_i
      rating = splitUser[2].to_i
        if usermovies.has_key?(user)
         temp = Array.new
         temp = usermovies[user]
         temp << [movie,rating]
         usermovies[user] = temp
        else 
         temp = Array.new
         temp << [movie,rating]
         usermovies[user] = temp
        end
    end  
    return usermovies  
  end
  def who_seen
    userTable = Hash.new
    @data.each do |line|
      splitUser = line.split("\t")
      user = splitUser[0].to_i
      movie = splitUser[1].to_i
      if userTable.has_key?(movie)
        temp = Array.new
        temp = userTable[movie]
        temp << user
        userTable[movie] = temp
      else 
        temp = Array.new
        temp << user
        userTable[movie] = temp
      end
    end
    return userTable  
  end
  def rating(u,m)  
    	movies_seen = @user_movies[u]
    	movies_seen.each do |movie,rating|
      if movie==m
        return rating
      end
    end
    return 0
  end
  def movies(u)
  	movies_seen = Array.new
    @user_movies.each do |k,v|
      if k.to_i==u.to_i
        v.each do |m|
          movies_seen << m[0]
        end
      end
    end
    return movies_seen
  end
  def viewers(m)
    @who_seen.each do |k,v|
      if k==m
        return v
      end
    end
    return 0
  end
  def db_predict(u,m)#Training table schema - user_id, rating, movie_id,Genre,age,gender - not super logically organized but I just needed it all in one place
  	
  	#Makes the training table
  	db = SQLite3::Database.open "mk-100.db"
	stm = db.prepare "CREATE TEMP TABLE Temp AS SELECT * FROM Data LIMIT #{@training_num}"
	rs = stm.execute
	stm = db.prepare "CREATE TEMP TABLE Temp2 AS SELECT Temp.user_id, Temp.rating, Item.movie_id,Item.Genre FROM Temp JOIN Item WHERE Temp.movie_id = Item.movie_id"
	rs = stm.execute
	stm = db.prepare "CREATE TEMP TABLE Training AS SELECT Temp2.*, User.age, User.gender FROM Temp2 JOIN User Where Temp2.user_id=User.user_id"
	rs = stm.execute
	stm = db.prepare "SELECT * FROM TRAINING"

	#GUESSWORK, finds average rating user gave movies of same genre
  	same_user_and_genre_count = 0
  	same_user_and_genre_sum = 0
  	stm = db.prepare "Select Genre FROM Item WHERE movie_id = #{m}"
  	rs = stm.execute
  	genre = nil
  	rs.each do |result|
  		genre = result[0]
  	end
  	genre = genre.to_i
  	stm = db.prepare "Select Genre,rating FROM TRAINING WHERE #{m}=user_id AND #{genre}=Genre"
  	rs = stm.execute
  	rs.each do |row|
  		same_user_and_genre_sum +=row[1].to_i
  		same_user_and_genre_count+=1
  	end
  	other_movies_same_genre = 0
  	if same_user_and_genre_count>0
  		other_movies_same_genre =  same_user_and_genre_sum/same_user_and_genre_count
  	else
  		other_movies_same_genre = 0#what it says on the tin, their average, as found form test data
  	end

  	same_demo_movie_rater_sum = 0
  	same_demo_movie_rater_count = 0

  	stm = db.prepare "SELECT age, gender FROM User WHERE user_id=#{u}"
  	rs = stm.execute
  	age=''
  	gender=''
  	rs.each do |row|
  		age = row[0]
  		gender = row[1]
  	end

  	age_minus_5 = (age -5).to_i
  	age_plus_5 = (age+5).to_i
  	stm = db.prepare "SELECT rating FROM Training WHERE (age<=#{age_plus_5} AND age>=#{age_minus_5}) AND #{genre}=Genre"
  	rs = stm.execute
  	rs.each do |row|
  		same_demo_movie_rater_sum+=row[0].to_i
  		same_demo_movie_rater_count+=1
  	end
  same_demo_movie_rater_mean = 0
  if same_demo_movie_rater_count>0
  	same_demo_movie_rater_mean = same_demo_movie_rater_sum/same_demo_movie_rater_count
  else
  	same_demo_movie_rater_mean = 0
  end
  	if same_demo_movie_rater_mean>0 && other_movies_same_genre>0
  		return (same_demo_movie_rater_mean+other_movies_same_genre)/2
  	elsif same_demo_movie_rater_mean>0
  		return same_demo_movie_rater_mean
  	elsif other_movies_same_genre>0
  		return other_movies_same_genre
  	else
  		return 0
  	end
  		
  		
  end
  def predict(u,m)
  	other_movies_seen = movies(u)
  	other_movies_seen.delete(m)
  	seen_what_u_saw = Array.new
  	other_movies_seen.each do |movie|
  		seen = viewers(movie)
  		seen.each do |p|
  			if ((!seen_what_u_saw.include? p) && (@who_seen[m].include? p)) && p!=u
  				seen_what_u_saw << p 
  			end
  		end
  	end
  	users_similar_to_u = Hash.new
  	seen_what_u_saw.each do |p|
  		pcent,number = @m.similarity(u,p)
  		users_similar_to_u[p] = [pcent,number]
  	end
  	users_similar_to_u = Hash[users_similar_to_u.sort_by do |k,v| [v[1],v[0]]end]
  	users_similar_to_u =  Hash[users_similar_to_u.to_a.reverse]
  	count = 0.0
  	sum = 0.0 	
  	users_similar_to_u.each do |k,v|
  		movies_they_seen = @user_movies[k]
  		movies_they_seen.each do |movie|
  			if movie[0]==m
  				count+=1
  				sum+=movie[1]
  			end
  		end
  	end
  	user_list = @user_movies[u]
  	actual = 0
  	user_list.each do |movie|
  		if movie[0] ==m
  			actual = movie[1]
  		end
  	end
  	db_guess = db_predict(u,m)
  	if(db_guess>0)
  		return ((sum/count)+db_guess)/2, actual
  	else
  		return sum/count,actual
  	end
  end
  def run_tests(stop)#stop = how far past the first value for predictor
  	results = Array.new
  	@data[@training_num..(stop+@training_num)].each do |line|
  		temp = line.split("\t")
  		temparr = Array.new
  		a,b=predict(temp[0].to_i,temp[1].to_i)
  		temparr<<a
  		temparr<<b
  		temparr<<temp[0]
  		temparr<<temp[1]
  		results<<temparr
  	end
  	m = MovieTest.new(results)
  	return m.to_a
  end
  #m1 = Movie_organizer.new()
end

class MovieTest
	def initialize(arg)
		@scores = arg
	end
	def mean
		count = 0.0
		sum = 0.0
		@scores.each do |score|
			sum+=(score[0]-score[1]).abs
			count+=1
		end
		return sum/count
	end
	def stdev
		count = 0.0
		sum = 0.0
		@scores.each do |score|
			sum+=(score[0]-score[1])**2
			count+=1
		end
		dev = Math.sqrt(sum/count)
		return dev
	end

	def to_a
		array = Array.new
		print @scores
		@scores.each do |score|
			array << [score[2],score[3],score[0],score[1]]
		end
		puts "mean error is:"
		puts mean
		puts "standard deviation is"
		puts stdev
		array.each do |line|
			puts "User #{line[0]} predicted rating of#{line[2]}, actual score of #{line[3]} with movie #{line[1]}"
		end
		
	end
end


p = Predictor.new(100,0)
p.run_tests(20)